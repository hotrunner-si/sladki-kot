import test from 'node:test'
import assert from 'node:assert/strict'
import { calculateProductForecast } from '../src/services/inventoryForecast.js'
const product = { lead_time_days: 2, safety_stock_days: 1 }
const c = (date, quantity) => ({ status: 'completed', completed_at: date, quantity })
test('normalna poraba brez dobave', () => assert.equal(calculateProductForecast({ product, counts: [c('2026-01-01', 50), c('2026-01-06', 30)] }).averageDailyUsage, 4))
test('upošteva dobavo med popisoma', () => assert.equal(calculateProductForecast({ product, counts: [c('2026-01-01', 50), c('2026-01-06', 40)], deliveries: [{ delivery_date: '2026-01-03', quantity: 20 }] }).averageDailyUsage, 6))
test('brez dovolj popisov', () => assert.equal(calculateProductForecast({ product, counts: [c('2026-01-01', 5)] }).hasEnoughData, false))
test('poraba je nic', () => assert.equal(calculateProductForecast({ product, counts: [c('2026-01-01', 5), c('2026-01-06', 5)] }).daysRemaining, null))
test('artikel brez zaloge', () => assert.equal(calculateProductForecast({ product, counts: [c('2026-01-01', 5), c('2026-01-06', 0)] }).status, 'out_of_stock'))
test('potrjena nova zaloga po zadnjem popisu se prišteje', () => assert.equal(calculateProductForecast({ product, counts: [c('2026-01-06', 30)], deliveries: [{ received_at: '2026-01-07', quantity: 12 }] }).currentQuantity, 42))
test('nov popis povozi starejšo novo zalogo', () => assert.equal(calculateProductForecast({ product, counts: [c('2026-01-06', 30), c('2026-01-08', 25)], deliveries: [{ received_at: '2026-01-07', quantity: 12 }] }).currentQuantity, 25))
