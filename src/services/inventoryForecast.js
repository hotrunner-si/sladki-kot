/** Deterministična napoved iz zaključenih popisov in dobav. */
export function calculateProductForecast({ counts = [], deliveries = [], product = {}, supplier = {} }) {
  const completed = counts.filter(c => c.status === 'completed' && c.quantity !== null && c.quantity !== undefined)
    .sort((a, b) => new Date(a.completed_at || a.date) - new Date(b.completed_at || b.date)).slice(-5)
  const currentQuantity = completed.length ? Number(completed.at(-1).quantity) : null
  const intervals = []
  for (let i = 1; i < completed.length; i++) {
    const previous = completed[i - 1], next = completed[i]
    const start = new Date(previous.completed_at || previous.date), end = new Date(next.completed_at || next.date)
    const days = (end - start) / 86400000
    if (days <= 0) continue
    const delivered = deliveries.filter(d => {
      const date = new Date(d.delivery_date || d.date)
      return date > start && date <= end
    }).reduce((sum, d) => sum + Number(d.quantity || 0), 0)
    const usage = Number(previous.quantity) + delivered - Number(next.quantity)
    if (usage >= 0) intervals.push({ usage, days })
  }
  const totalDays = intervals.reduce((s, i) => s + i.days, 0)
  const totalUsage = intervals.reduce((s, i) => s + i.usage, 0)
  const hasEnoughData = intervals.length > 0 && totalDays > 0
  const averageDailyUsage = hasEnoughData ? totalUsage / totalDays : null
  const daysRemaining = currentQuantity !== null && averageDailyUsage > 0 ? currentQuantity / averageDailyUsage : null
  const effectiveLeadTimeDays = Number(product.lead_time_days ?? supplier.default_lead_time_days ?? 0)
  const safetyStockDays = Number(product.safety_stock_days ?? 0)
  const reorderThresholdDays = effectiveLeadTimeDays + safetyStockDays
  let status = 'unknown', reorderInDays = null
  if (currentQuantity === 0) status = 'out_of_stock'
  else if (daysRemaining !== null) {
    reorderInDays = daysRemaining - reorderThresholdDays
    status = daysRemaining <= reorderThresholdDays ? 'critical' : daysRemaining <= reorderThresholdDays + 3 ? 'warning' : 'ok'
  }
  return { currentQuantity, averageDailyUsage, daysRemaining, effectiveLeadTimeDays, safetyStockDays, reorderThresholdDays, reorderInDays, status, hasEnoughData }
}

export const statusText = { critical: 'NAROČI DANES', warning: 'Naroči kmalu', ok: 'Zaloga OK', unknown: 'Ni dovolj podatkov', out_of_stock: 'NI ZALOGE' }
