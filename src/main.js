import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import './assets/main.css'
import './assets/products.css'
import './assets/products-list.css'
import './assets/more.css'
import './assets/admin-lists.css'
createApp(App).use(router).mount('#app')
