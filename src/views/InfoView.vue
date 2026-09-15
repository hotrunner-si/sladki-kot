<script setup>
import { nextTick, ref } from 'vue'

const panorama = ref(null)
const isPanoramaOpen = ref(false)
let dragStartX = 0
let dragScrollLeft = 0
let isDragging = false

async function openPanorama() {
  isPanoramaOpen.value = true
  await nextTick()
  centerPanorama()
  panorama.value?.focus()
}

function centerPanorama() {
  const viewer = panorama.value
  if (viewer) viewer.scrollLeft = (viewer.scrollWidth - viewer.clientWidth) / 2.1
}

function closePanorama() {
  isPanoramaOpen.value = false
}

function startDrag(event) {
  isDragging = true
  dragStartX = event.clientX
  dragScrollLeft = panorama.value.scrollLeft
  panorama.value.setPointerCapture(event.pointerId)
}

function drag(event) {
  if (!isDragging) return
  panorama.value.scrollLeft = dragScrollLeft - (event.clientX - dragStartX)
}

function stopDrag(event) {
  if (!isDragging) return
  isDragging = false
  panorama.value.releasePointerCapture?.(event.pointerId)
}

function panWithKeyboard(event) {
  if (event.key === 'Escape') closePanorama()
  if (event.key === 'ArrowLeft') panorama.value.scrollBy({ left: -160, behavior: 'smooth' })
  if (event.key === 'ArrowRight') panorama.value.scrollBy({ left: 160, behavior: 'smooth' })
}
</script>

<template>
  <section class="info-page">
    <p class="eyebrow">Info</p>

    <nav class="info-list" aria-label="Informacije">
      <button
        class="info-list__button"
        @click="openPanorama"
      >
        Gore Kamniških Alp
      </button>
    </nav>

    <Teleport to="body">
      <section v-if="isPanoramaOpen" class="panorama-overlay" role="dialog" aria-modal="true" aria-label="Gore Kamniških Alp" @click.self="closePanorama">
        <button class="panorama-close" type="button" aria-label="Zapri prikaz gora" @click="closePanorama">×</button>
        <div
          ref="panorama"
          class="panorama-viewer"
          tabindex="0"
          aria-label="Panoramski prikaz Kamniških Alp. Za pomik vlecite sliko levo ali desno."
          @keydown="panWithKeyboard"
          @pointerdown="startDrag"
          @pointermove="drag"
          @pointerup="stopDrag"
          @pointercancel="stopDrag"
        >
          <img src="/kamniske-alpe-risane-big.png" alt="Risani prikaz gora Kamniških Alp z imeni in nadmorskimi višinami." draggable="false" @load="centerPanorama" />
        </div>
        <p class="panorama-hint">Vlecite levo ali desno za ogled celotne panorame.</p>
      </section>
    </Teleport>
  </section>
</template>
