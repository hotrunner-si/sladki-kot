import { createRouter, createWebHistory } from 'vue-router'
import { useAuth } from '../composables/useAuth'
import LoginView from '../views/LoginView.vue'
import DashboardView from '../views/DashboardView.vue'
import CountHomeView from '../views/CountHomeView.vue'
import InventoryCountView from '../views/InventoryCountView.vue'
import InventoryHistoryView from '../views/InventoryHistoryView.vue'
import DeliveriesView from '../views/DeliveriesView.vue'
import ProductsView from '../views/ProductsView.vue'
import SuppliersView from '../views/SuppliersView.vue'
import MoreView from '../views/MoreView.vue'
import UsersView from '../views/UsersView.vue'
const routes = [{ path: '/login', component: LoginView, meta: { public: true } },{ path: '/', redirect: '/dashboard' },{ path: '/dashboard', component: DashboardView },{ path: '/count', component: CountHomeView },{ path: '/count/new', component: InventoryCountView },{ path: '/history-counts', component: InventoryHistoryView },{ path: '/counts', redirect: '/history-counts' },{ path: '/deliveries', component: DeliveriesView, meta: { admin: true } },{ path: '/products', component: ProductsView },{ path: '/suppliers', component: SuppliersView, meta: { admin: true } },{ path: '/users', component: UsersView, meta: { admin: true } },{ path: '/more', component: MoreView, meta: { admin: true } }]
const router = createRouter({ history: createWebHistory(), routes })
router.beforeEach(async to => { const auth = useAuth(); if (!auth.state.ready) await auth.initialize(); if (to.meta.public) return auth.state.user ? (auth.isAdmin() ? '/dashboard' : '/count') : true; if (!auth.state.user) return '/login'; if (to.meta.admin && !auth.isAdmin()) return '/count'; return true })
export default router
