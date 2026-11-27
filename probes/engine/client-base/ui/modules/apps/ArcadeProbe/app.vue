<template>
  <div class="probe">
    <div v-for="(value, key) in fields" :key="key">{{ key }}: {{ value }}</div>
    <button @click="pingGame">Ping game</button>
  </div>
</template>

<script setup>
import { ref, onMounted } from "vue"
import { useEvents } from "@/services/events"
import { useBridge } from "@/bridge"

const { api } = useBridge()
const events = useEvents()
const fields = ref({})

events.on("ArcadeProbe", data => {
  fields.value = { ...(data || {}) }
})

events.on("ArcadeProbeSnapshot", data => {
  fields.value = {}
  fields.value = { ...(data || {}) }
})

function pingGame() {
  api.engineLua("if arcadeProbeGame then arcadeProbeGame.uiPing() end")
}

onMounted(() => {
  api.engineLua('log("I", "arcadeProbe", "[arcade-probe] app mounted")')
})
</script>

<style scoped>
.probe {
  padding: 0.5rem;
  background: rgba(0, 0, 0, 0.6);
  color: white;
}
</style>
