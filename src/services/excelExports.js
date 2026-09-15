import { supabase } from '../lib/supabase'
import { getProducts } from './data'

const START_DATE = '2026-09-15'
const DATE_PARTS = new Intl.DateTimeFormat('en-CA', {
  timeZone: 'Europe/Ljubljana', year: 'numeric', month: '2-digit', day: '2-digit',
})
const DATE_LABEL = new Intl.DateTimeFormat('sl-SI', {
  timeZone: 'Europe/Ljubljana', day: '2-digit', month: '2-digit', year: 'numeric',
})

function dayKey(value) {
  const parts = Object.fromEntries(DATE_PARTS.formatToParts(new Date(value)).map(part => [part.type, part.value]))
  return `${parts.year}-${parts.month}-${parts.day}`
}

function dateRange(start, end) {
  const dates = []
  const cursor = new Date(`${start}T00:00:00Z`)
  const finalDate = new Date(`${end}T00:00:00Z`)
  while (cursor <= finalDate) {
    dates.push(cursor.toISOString().slice(0, 10))
    cursor.setUTCDate(cursor.getUTCDate() + 1)
  }
  return dates
}

function displayDate(key) {
  return DATE_LABEL.format(new Date(`${key}T12:00:00Z`))
}

async function downloadWorkbook(workbook, name) {
  const { writeFileXLSX } = await import('xlsx')
  writeFileXLSX(workbook, name, { compression: true })
}

function formatSheet(utils, sheet, headerRows, productCount) {
  sheet['!cols'] = [{ wch: 32 }, { wch: 10 }, ...Array.from({ length: Math.max(0, (sheet['!ref'] ? utils.decode_range(sheet['!ref']).e.c + 1 : 2) - 2) }, () => ({ wch: 11 }))]
  sheet['!rows'] = Array.from({ length: headerRows }, () => ({ hpt: 23 }))
  const range = utils.decode_range(sheet['!ref'])
  for (let row = 0; row <= range.e.r; row += 1) {
    for (let column = 0; column <= range.e.c; column += 1) {
      const cell = sheet[utils.encode_cell({ r: row, c: column })]
      if (!cell) continue
      cell.s = {
        font: { name: 'Aptos', sz: 10, bold: row < headerRows },
        alignment: { vertical: 'center', horizontal: column < 2 ? 'left' : 'center' },
        fill: row < headerRows ? { fgColor: { rgb: 'AD3D63' } } : undefined,
      }
      if (row < headerRows) cell.s.font.color = { rgb: 'FFFFFF' }
    }
  }
  for (let row = headerRows; row < headerRows + productCount; row += 1) {
    const nameCell = sheet[utils.encode_cell({ r: row, c: 0 })]
    if (nameCell) nameCell.s = { ...nameCell.s, font: { ...nameCell.s.font, bold: true } }
  }
}

async function fetchExportData() {
  const [products, countsResult, itemsResult, deliveriesResult] = await Promise.all([
    getProducts(),
    supabase.from('inventory_counts').select('id,status,started_at,submitted_at,completed_at,updated_at').neq('status', 'draft').order('started_at'),
    supabase.from('inventory_count_items').select('inventory_count_id,product_id,quantity'),
    supabase.from('delivery_items').select('product_id,quantity,received_at').not('received_at', 'is', null),
  ])
  if (countsResult.error || itemsResult.error || deliveriesResult.error) throw countsResult.error || itemsResult.error || deliveriesResult.error
  return { products, counts: countsResult.data, items: itemsResult.data, deliveries: deliveriesResult.data }
}

export async function exportProductData() {
  const { utils } = await import('xlsx')
  const { products, counts, items, deliveries } = await fetchExportData()
  const today = dayKey(new Date())
  const days = dateRange(START_DATE, today)
  const completedById = new Map(counts.filter(count => count.status === 'completed' && count.completed_at).map(count => [count.id, count]))
  const itemsByCount = new Map()
  for (const item of items) {
    if (!completedById.has(item.inventory_count_id)) continue
    if (!itemsByCount.has(item.inventory_count_id)) itemsByCount.set(item.inventory_count_id, [])
    itemsByCount.get(item.inventory_count_id).push(item)
  }
  const receivedByProductAndDay = new Map()
  for (const delivery of deliveries) {
    const key = `${delivery.product_id}:${dayKey(delivery.received_at)}`
    receivedByProductAndDay.set(key, (receivedByProductAndDay.get(key) || 0) + Number(delivery.quantity))
  }

  const headerDates = ['Izdelek', 'Enota']
  const headerTypes = ['', '']
  const merges = []
  days.forEach((day, index) => {
    const column = 2 + index * 3
    headerDates.push(displayDate(day), '', '')
    headerTypes.push('Dobava', 'Poraba', 'Zaloga')
    merges.push({ s: { r: 0, c: column }, e: { r: 0, c: column + 2 } })
  })
  const rows = [headerDates, headerTypes]
  for (const product of products) {
    const historicalCounts = [...completedById.values()]
      .filter(count => dayKey(count.completed_at) < START_DATE)
      .sort((a, b) => new Date(a.completed_at) - new Date(b.completed_at))
    let balance = null
    for (const count of historicalCounts) {
      const counted = itemsByCount.get(count.id)?.find(item => item.product_id === product.id)
      if (counted) balance = Number(counted.quantity)
    }
    const row = [product.name, product.unit]
    for (const day of days) {
      const delivery = receivedByProductAndDay.get(`${product.id}:${day}`) || 0
      if (balance !== null) balance += delivery
      row.push(delivery || '-', '', balance ?? '-')
    }
    rows.push(row)
  }
  const sheet = utils.aoa_to_sheet(rows)
  sheet['!merges'] = merges
  formatSheet(utils, sheet, 2, products.length)
  const workbook = utils.book_new()
  utils.book_append_sheet(workbook, sheet, 'Dnevna zaloga')
  await downloadWorkbook(workbook, 'sladki-kot-izdelki.xlsx')
}

export async function exportInventoryCounts() {
  const { utils } = await import('xlsx')
  const { products, counts, items } = await fetchExportData()
  const includedCounts = counts
    .map(count => ({ ...count, date: count.submitted_at || count.completed_at || count.updated_at || count.started_at }))
    .filter(count => dayKey(count.date) >= START_DATE)
    .sort((a, b) => new Date(a.date) - new Date(b.date))
  const itemsByCountAndProduct = new Map(items.map(item => [`${item.inventory_count_id}:${item.product_id}`, Number(item.quantity)]))
  const rows = [
    ['Izdelek', 'Enota', ...includedCounts.map(count => `${displayDate(dayKey(count.date))} ${new Intl.DateTimeFormat('sl-SI', { timeZone: 'Europe/Ljubljana', hour: '2-digit', minute: '2-digit' }).format(new Date(count.date))}`)],
    ...products.map(product => [product.name, product.unit, ...includedCounts.map(count => itemsByCountAndProduct.has(`${count.id}:${product.id}`) ? itemsByCountAndProduct.get(`${count.id}:${product.id}`) : '-')]),
  ]
  const sheet = utils.aoa_to_sheet(rows)
  formatSheet(utils, sheet, 1, products.length)
  const workbook = utils.book_new()
  utils.book_append_sheet(workbook, sheet, 'Popisi')
  await downloadWorkbook(workbook, 'sladki-kot-popisi.xlsx')
}
