import { BaseEdge, EdgeLabelRenderer, getSmoothStepPath } from '@xyflow/react'

export default function StepEdge({
  id,
  sourceX,
  sourceY,
  targetX,
  targetY,
  sourcePosition,
  targetPosition,
  data,
  selected,
}) {
  const edgeType = data?.edgeType || 'success'
  const isFailure = edgeType === 'failure'
  const isActive = data?.active === true
  const isCompleted = data?.completed === true

  const [edgePath, labelX, labelY] = getSmoothStepPath({
    sourceX,
    sourceY,
    targetX,
    targetY,
    sourcePosition,
    targetPosition,
    borderRadius: 16,
  })

  const strokeColor = isActive
    ? 'rgba(59,130,246,0.7)'
    : isCompleted
    ? 'rgba(16,185,129,0.6)'
    : isFailure
    ? 'rgba(252, 129, 129, 0.45)'
    : selected
    ? 'rgba(99, 179, 237, 0.75)'
    : 'rgba(255, 255, 255, 0.1)'

  const strokeWidth = isActive || isCompleted ? 2 : selected ? 1.8 : 1.2

  const style = {
    stroke: strokeColor,
    strokeWidth,
    strokeDasharray: isActive ? '6 3' : isFailure ? '5 3' : 'none',
    transition: 'stroke 0.3s ease, stroke-width 0.3s ease',
  }

  if (isActive) {
    style.animation = 'edgeFlow 0.6s linear infinite'
  }

  // Determine CSS class for the edge wrapper
  const className = isActive ? 'edge-active' : isCompleted ? 'edge-completed' : ''

  return (
    <g className={className}>
      {/* Fat invisible path for click targeting */}
      <path
        d={edgePath}
        fill="none"
        stroke="transparent"
        strokeWidth={20}
        style={{ cursor: 'pointer' }}
      />
      <BaseEdge
        id={id}
        path={edgePath}
        style={style}
      />
      {data?.label && (
        <EdgeLabelRenderer>
          <div
            className="edge-label"
            style={{
              position: 'absolute',
              transform: `translate(-50%, -50%) translate(${labelX}px,${labelY}px)`,
              pointerEvents: 'none',
            }}
          >
            {data.label}
          </div>
        </EdgeLabelRenderer>
      )}
    </g>
  )
}
