import { useCallback, useEffect, useRef } from 'react'
import {
  ReactFlow,
  Background,
  MiniMap,
  useNodesState,
  useEdgesState,
  addEdge,
  useReactFlow,
  ReactFlowProvider,
} from '@xyflow/react'
import StepNode from './StepNode'
import StepEdge from './StepEdge'

// Custom node/edge types
const nodeTypes = { step: StepNode }
const edgeTypes = { step: StepEdge }

// Friendly display name derivation (mirrors Swift GraphNode.displayName)
function deriveDisplayName(node) {
  const { id, type, label, stepConfig } = node
  const cfg = stepConfig || {}

  // If label was explicitly set (not auto-generated), use it
  if (label && label !== id && !/^[a-z_]+_\d+$/.test(label)) {
    return label
  }

  switch (type) {
    case 'tool': {
      const tool = cfg.tool_name
      const action = cfg.action
      if (tool) {
        const name = tool.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
        return action ? `${name} \u2022 ${action}` : name
      }
      return 'Tool Step'
    }
    case 'condition': return 'Condition'
    case 'code': return `Code (${cfg.language || 'js'})`
    case 'agent': {
      if (cfg.agent_name) return cfg.agent_name.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
      return 'Agent'
    }
    case 'delay': return cfg.seconds ? `Delay ${cfg.seconds}s` : 'Delay'
    case 'webhook_out': return 'Webhook'
    case 'approval': return cfg.title || 'Approval'
    case 'parallel': return 'Parallel'
    case 'for_each': return 'For Each'
    case 'sub_workflow': return 'Sub-Workflow'
    case 'transform': return 'Transform'
    case 'waitpoint': return cfg.label || 'Waitpoint'
    default: return type.replace(/_/g, ' ').replace(/\b\w/g, c => c.toUpperCase())
  }
}

// ===== Auto-layout: DAG tree layout when positions are missing =====
function autoLayout(serverNodes, serverEdges) {
  // Build adjacency map from edges
  const children = {} // sourceId -> [targetId]
  const parents = {}  // targetId -> [sourceId]
  for (const e of serverEdges) {
    if (!children[e.from]) children[e.from] = []
    children[e.from].push(e.to)
    if (!parents[e.to]) parents[e.to] = []
    parents[e.to].push(e.from)
  }

  // Find entry points (no parents, or marked as entry)
  const entryPoints = serverNodes.filter(
    n => n.is_entry_point || !parents[n.id] || parents[n.id].length === 0
  )
  if (entryPoints.length === 0 && serverNodes.length > 0) {
    entryPoints.push(serverNodes[0])
  }

  // BFS to assign levels
  const levels = {} // nodeId -> level (depth)
  const visited = new Set()
  const queue = entryPoints.map(n => ({ id: n.id, level: 0 }))
  for (const ep of queue) {
    levels[ep.id] = 0
    visited.add(ep.id)
  }

  while (queue.length > 0) {
    const { id, level } = queue.shift()
    const kids = children[id] || []
    for (const kid of kids) {
      if (!visited.has(kid)) {
        visited.add(kid)
        levels[kid] = level + 1
        queue.push({ id: kid, level: level + 1 })
      }
    }
  }

  // Assign unvisited nodes to their own levels
  let maxLevel = Math.max(0, ...Object.values(levels))
  for (const n of serverNodes) {
    if (!visited.has(n.id)) {
      maxLevel++
      levels[n.id] = maxLevel
    }
  }

  // Group nodes by level
  const levelGroups = {}
  for (const n of serverNodes) {
    const lvl = levels[n.id] || 0
    if (!levelGroups[lvl]) levelGroups[lvl] = []
    levelGroups[lvl].push(n.id)
  }

  // Position: tighter spacing for app-icon nodes
  const positions = {}
  const HORIZONTAL_GAP = 140
  const VERTICAL_GAP = 140

  for (const [lvl, ids] of Object.entries(levelGroups)) {
    const y = parseInt(lvl) * VERTICAL_GAP
    const totalWidth = (ids.length - 1) * HORIZONTAL_GAP
    const startX = -totalWidth / 2
    ids.forEach((id, i) => {
      positions[id] = { x: startX + i * HORIZONTAL_GAP, y }
    })
  }

  return positions
}

// Convert server graph data to React Flow format
function toFlowNodes(serverNodes, serverEdges) {
  // Check if ANY node lacks a position
  const needsLayout = serverNodes.some(n => !n.position || (n.position.x === 0 && n.position.y === 0))
  const layoutPositions = needsLayout ? autoLayout(serverNodes, serverEdges || []) : null

  return serverNodes.map(n => {
    let position
    if (n.position && (n.position.x !== 0 || n.position.y !== 0)) {
      position = n.position
    } else if (layoutPositions && layoutPositions[n.id]) {
      position = layoutPositions[n.id]
    } else {
      position = { x: 0, y: 0 }
    }

    return {
      id: n.id,
      type: 'step',
      position,
      data: {
        stepKey: n.id,
        stepType: n.type,
        displayName: deriveDisplayName(n),
        isEntryPoint: n.is_entry_point || false,
        onFailure: n.on_failure,
        status: null,
        durationMs: null,
        agentTokens: null,
      },
    }
  })
}

function toFlowEdges(serverEdges) {
  return serverEdges.map(e => ({
    id: `${e.from}-${e.to}-${e.type}`,
    source: e.from,
    target: e.to,
    sourceHandle: e.type === 'failure' ? 'failure' : 'success',
    targetHandle: 'in',
    type: 'step',
    data: { edgeType: e.type, label: e.label },
  }))
}

// Send message to Swift
function postToSwift(type, payload) {
  try {
    window.webkit?.messageHandlers?.canvas?.postMessage({ type, payload })
  } catch (e) {
    console.log('[Bridge]', type, payload)
  }
}

function Flow() {
  const [nodes, setNodes, onNodesChange] = useNodesState([])
  const [edges, setEdges, onEdgesChange] = useEdgesState([])
  const { fitView } = useReactFlow()
  const lastGraphRef = useRef(null)
  const fitViewTimerRef = useRef(null)

  // Robust fitView — retries until viewport is sized
  const doFitView = useCallback(() => {
    if (fitViewTimerRef.current) clearTimeout(fitViewTimerRef.current)
    // Multiple attempts to handle initial render timing
    const attempts = [50, 200, 500]
    attempts.forEach(delay => {
      fitViewTimerRef.current = setTimeout(() => {
        fitView({ padding: 0.3, duration: 200, maxZoom: 1.0 })
      }, delay)
    })
  }, [fitView])

  // Handle new edge connection
  const onConnect = useCallback(
    (params) => {
      const edgeType = params.sourceHandle === 'failure' ? 'failure' : 'success'
      const newEdge = {
        ...params,
        id: `${params.source}-${params.target}-${edgeType}`,
        type: 'step',
        data: { edgeType, label: null },
      }
      setEdges(eds => addEdge(newEdge, eds))
      postToSwift('edgeCreated', {
        from: params.source,
        to: params.target,
        edgeType,
        sourceHandle: params.sourceHandle,
      })
    },
    [setEdges]
  )

  // Node click -> select
  const onNodeClick = useCallback((_, node) => {
    postToSwift('nodeSelected', { id: node.id })
  }, [])

  // Node double-click -> edit
  const onNodeDoubleClick = useCallback((_, node) => {
    postToSwift('nodeDoubleClicked', { id: node.id })
  }, [])

  // Context menu on node
  const onNodeContextMenu = useCallback((event, node) => {
    event.preventDefault()
    postToSwift('nodeContextMenu', { id: node.id, x: event.clientX, y: event.clientY })
  }, [])

  // Node drag end -> save position
  const onNodeDragStop = useCallback((_, node) => {
    postToSwift('nodeMoved', {
      id: node.id,
      x: node.position.x,
      y: node.position.y,
    })
  }, [])

  // Nodes deleted
  const onNodesDelete = useCallback((deletedNodes) => {
    postToSwift('nodesDeleted', { ids: deletedNodes.map(n => n.id) })
  }, [])

  // Edges deleted
  const onEdgesDelete = useCallback((deletedEdges) => {
    postToSwift('edgesDeleted', {
      edges: deletedEdges.map(e => ({
        from: e.source,
        to: e.target,
        edgeType: e.data?.edgeType || 'success',
      })),
    })
  }, [])

  // Selection change
  const onSelectionChange = useCallback(({ nodes: selectedNodes }) => {
    if (selectedNodes.length > 0) {
      postToSwift('selectionChanged', { ids: selectedNodes.map(n => n.id) })
    }
  }, [])

  // Pane click -> deselect
  const onPaneClick = useCallback(() => {
    postToSwift('selectionChanged', { ids: [] })
  }, [])

  // ===== Bridge: Swift -> JS commands =====
  useEffect(() => {
    window.bridge = {
      loadGraph: (data) => {
        const { nodes: serverNodes, edges: serverEdges } = data
        const flowNodes = toFlowNodes(serverNodes, serverEdges)
        const flowEdges = toFlowEdges(serverEdges)
        lastGraphRef.current = data
        setNodes(flowNodes)
        setEdges(flowEdges)
        doFitView()
      },

      updateNodeStatus: (statuses) => {
        setNodes(nds =>
          nds.map(n => {
            const s = statuses[n.id]
            if (s) {
              return {
                ...n,
                data: {
                  ...n.data,
                  status: s.status,
                  durationMs: s.duration_ms,
                },
              }
            }
            return n
          })
        )
      },

      clearStatus: () => {
        setNodes(nds =>
          nds.map(n => ({
            ...n,
            data: { ...n.data, status: null, durationMs: null, agentTokens: null },
          }))
        )
      },

      selectNode: (id) => {
        setNodes(nds =>
          nds.map(n => ({
            ...n,
            selected: n.id === id,
          }))
        )
      },

      fitView: () => {
        fitView({ padding: 0.3, duration: 200, maxZoom: 1.0 })
      },

      setAgentTokens: (tokens) => {
        setNodes(nds =>
          nds.map(n => {
            const t = tokens[n.id]
            if (t !== undefined) {
              return { ...n, data: { ...n.data, agentTokens: t || null } }
            }
            return n
          })
        )
      },

      addNode: (nodeData) => {
        const flowNode = {
          id: nodeData.id,
          type: 'step',
          position: nodeData.position || { x: 300, y: 300 },
          data: {
            stepKey: nodeData.id,
            stepType: nodeData.type,
            displayName: deriveDisplayName(nodeData),
            isEntryPoint: nodeData.is_entry_point || false,
            onFailure: nodeData.on_failure,
            status: null,
            durationMs: null,
            agentTokens: null,
          },
          selected: true,
        }
        setNodes(nds => [...nds.map(n => ({ ...n, selected: false })), flowNode])
      },

      removeNode: (id) => {
        setNodes(nds => nds.filter(n => n.id !== id))
        setEdges(eds => eds.filter(e => e.source !== id && e.target !== id))
      },

      // Edge animation bridge methods
      updateEdgeStatus: (edgeStatuses) => {
        // edgeStatuses: { edgeId: { active: bool, completed: bool } }
        setEdges(eds =>
          eds.map(e => {
            const s = edgeStatuses[e.id]
            if (s) {
              return {
                ...e,
                data: { ...e.data, active: s.active || false, completed: s.completed || false },
              }
            }
            return e
          })
        )
      },

      highlightPath: (fromKey, toKey) => {
        setEdges(eds =>
          eds.map(e => {
            if (e.source === fromKey && e.target === toKey) {
              return { ...e, data: { ...e.data, active: true } }
            }
            return e
          })
        )
      },

      clearEdgeHighlights: () => {
        setEdges(eds =>
          eds.map(e => ({
            ...e,
            data: { ...e.data, active: false, completed: false },
          }))
        )
      },
    }

    postToSwift('ready', {})

    return () => {
      if (fitViewTimerRef.current) clearTimeout(fitViewTimerRef.current)
      delete window.bridge
    }
  }, [setNodes, setEdges, fitView, doFitView])

  return (
    <ReactFlow
      nodes={nodes}
      edges={edges}
      onNodesChange={onNodesChange}
      onEdgesChange={onEdgesChange}
      onConnect={onConnect}
      onNodeClick={onNodeClick}
      onNodeDoubleClick={onNodeDoubleClick}
      onNodeContextMenu={onNodeContextMenu}
      onNodeDragStop={onNodeDragStop}
      onNodesDelete={onNodesDelete}
      onEdgesDelete={onEdgesDelete}
      onSelectionChange={onSelectionChange}
      onPaneClick={onPaneClick}
      nodeTypes={nodeTypes}
      edgeTypes={edgeTypes}
      defaultEdgeOptions={{ type: 'step' }}
      fitView
      fitViewOptions={{ padding: 0.3, maxZoom: 1.0 }}
      snapToGrid
      snapGrid={[20, 20]}
      deleteKeyCode={['Delete', 'Backspace']}
      multiSelectionKeyCode="Shift"
      selectionOnDrag={false}
      panOnDrag
      selectionMode="partial"
      minZoom={0.1}
      maxZoom={2.5}
      proOptions={{ hideAttribution: true }}
      connectionLineStyle={{ stroke: 'var(--accent)', strokeWidth: 2, strokeDasharray: '5 3' }}
      connectOnClick={false}
      elevateEdgesOnSelect
      elevateNodesOnSelect
    >
      <Background variant="dots" gap={20} size={1} color="rgba(255,255,255,0.08)" />
      <MiniMap
        position="top-right"
        nodeStrokeWidth={0}
        nodeBorderRadius={3}
        nodeColor={(n) => {
          const status = n.data?.status
          if (status === 'running') return 'rgba(236, 201, 75, 0.7)'
          if (status === 'failed' || status === 'error') return 'rgba(252, 129, 129, 0.7)'
          if (status === 'success' || status === 'completed') return 'rgba(72, 187, 120, 0.7)'
          return 'rgba(255, 255, 255, 0.18)'
        }}
        maskColor="rgba(99, 179, 237, 0.04)"
        style={{ width: 160, height: 100, borderRadius: 10 }}
        pannable
        zoomable
      />
    </ReactFlow>
  )
}

export default function App() {
  return (
    <ReactFlowProvider>
      <div style={{ width: '100vw', height: '100vh' }}>
        <Flow />
      </div>
    </ReactFlowProvider>
  )
}
