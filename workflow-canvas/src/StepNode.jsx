import React, { memo } from 'react'
import { Handle, Position } from '@xyflow/react'

// ── Step type config: color, label, icon ──
const STEP_TYPES = {
  tool:         { color: '#FF7A3D', label: 'Tool',         emoji: '🔧' },
  code:         { color: '#A78BFA', label: 'Code',         emoji: '{ }' },
  agent:        { color: '#22D3EE', label: 'Agent',        emoji: '🤖' },
  sub_workflow: { color: '#3B82F6', label: 'Sub-Flow',     emoji: '🔀' },
  condition:    { color: '#FBBF24', label: 'Condition',    emoji: '◇' },
  parallel:     { color: '#8B5CF6', label: 'Parallel',     emoji: '≡' },
  for_each:     { color: '#0EA5E9', label: 'For Each',     emoji: '↻' },
  delay:        { color: '#F59E0B', label: 'Delay',        emoji: '⏱' },
  noop:         { color: '#64748B', label: 'No-op',        emoji: '○' },
  webhook_out:  { color: '#10B981', label: 'Webhook',      emoji: '🔗' },
  custom:       { color: '#94A3B8', label: 'Custom',       emoji: '✦' },
  approval:     { color: '#FBBF24', label: 'Approval',     emoji: '✓' },
  waitpoint:    { color: '#FB923C', label: 'Wait',         emoji: '⏸' },
  transform:    { color: '#14B8A6', label: 'Transform',    emoji: '⇄' },
}

const FALLBACK = { color: '#94A3B8', label: 'Step', emoji: '●' }

function formatDuration(ms) {
  if (!ms) return null
  if (ms < 1000) return `${ms}ms`
  const s = ms / 1000
  if (s < 60) return `${s.toFixed(1)}s`
  return `${Math.floor(s / 60)}m${Math.floor(s % 60)}s`
}

// Status icon SVGs
const StatusCheck = () => (
  <svg width="10" height="10" viewBox="0 0 16 16" fill="none">
    <path d="M3 8l4 4 6-7" stroke="white" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"/>
  </svg>
)
const StatusX = () => (
  <svg width="10" height="10" viewBox="0 0 16 16" fill="none">
    <path d="M4 4l8 8M12 4l-8 8" stroke="white" strokeWidth="2.2" strokeLinecap="round"/>
  </svg>
)

function StepNode({ data, selected }) {
  const meta = STEP_TYPES[data.stepType] || FALLBACK
  const duration = formatDuration(data.durationMs)
  const hasFailureHandle = data.stepType === 'condition' || data.onFailure

  const classes = ['sn']
  if (selected) classes.push('sn--sel')
  if (data.status) classes.push(`sn--${data.status}`)
  if (data.isEntryPoint) classes.push('sn--entry')

  return (
    <div className={classes.join(' ')} style={{ '--c': meta.color }}>
      {/* Input handle — top center */}
      {!data.isEntryPoint && (
        <Handle type="target" position={Position.Top} id="in" />
      )}

      {/* ── App icon ── */}
      <div className="sn__icon">{meta.emoji}</div>

      {/* ── Name ── */}
      <div className="sn__name">{data.displayName}</div>

      {/* ── Type label ── */}
      <div className="sn__type">{meta.label}</div>

      {/* Duration when running/completed */}
      {duration && <div className="sn__dur">{duration}</div>}

      {/* Status badge */}
      {data.status && data.status !== 'pending' && (
        <div className={`sn__badge sn__badge--${data.status}`}>
          {(data.status === 'success' || data.status === 'completed') && <StatusCheck />}
          {(data.status === 'failed' || data.status === 'error') && <StatusX />}
        </div>
      )}

      {/* Entry point bolt */}
      {data.isEntryPoint && (
        <div className="sn__entry">⚡</div>
      )}

      {/* Agent token streaming */}
      {data.agentTokens && (
        <div className="sn__tokens">{data.agentTokens}</div>
      )}

      {/* Progress bar for running state */}
      {data.status === 'running' && (
        <div className="sn__progress" />
      )}

      {/* Output handles — bottom */}
      <Handle
        type="source"
        position={Position.Bottom}
        id="success"
        className="handle--success"
        style={hasFailureHandle ? { left: '35%' } : undefined}
      />
      {hasFailureHandle && (
        <Handle
          type="source"
          position={Position.Bottom}
          id="failure"
          className="handle--failure"
          style={{ left: '65%' }}
        />
      )}
    </div>
  )
}

export default memo(StepNode)
