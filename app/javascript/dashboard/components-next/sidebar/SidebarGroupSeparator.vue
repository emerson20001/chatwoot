<script setup>
import Icon from 'next/icon/Icon.vue';
import { useSidebarContext } from './provider';

defineProps({
  label: {
    type: String,
    default: '',
  },
  icon: {
    type: String,
    default: '',
  },
});

const { isCollapsed } = useSidebarContext();
</script>

<template>
  <div
    v-show="!isCollapsed"
    class="flex items-center gap-2 px-2 py-1.5 rounded-lg h-8 text-n-slate-10 select-none pointer-events-none"
  >
    <Icon v-if="icon" :icon="icon" class="size-5" />
    <span class="text-sm font-medium leading-5 flex-grow">
      {{ label }}
    </span>
  </div>
</template>
