<script setup>
import { ref, useTemplateRef, provide, computed, watch } from 'vue';
import { useElementSize } from '@vueuse/core';

const props = defineProps({
  index: {
    type: Number,
    default: 0,
  },
  border: {
    type: Boolean,
    default: true,
  },
  variant: {
    type: String,
    default: 'default',
  },
});

const emit = defineEmits(['change']);

const tabsContainer = useTemplateRef('tabsContainer');
const tabsList = useTemplateRef('tabsList');

const { width: containerWidth } = useElementSize(tabsContainer);
const { width: listWidth } = useElementSize(tabsList);

const hasScroll = ref(false);

const activeIndex = computed({
  get: () => props.index,
  set: newValue => {
    emit('change', newValue);
  },
});

const isPillVariant = computed(() => props.variant === 'pill');

provide('activeIndex', activeIndex);
provide('updateActiveIndex', index => {
  activeIndex.value = index;
});

const computeScrollWidth = () => {
  if (tabsContainer.value && tabsList.value) {
    hasScroll.value = tabsList.value.scrollWidth > tabsList.value.clientWidth;
  }
};

const onScrollClick = direction => {
  if (tabsContainer.value && tabsList.value) {
    let scrollPosition = tabsList.value.scrollLeft;
    scrollPosition += direction === 'left' ? -100 : 100;
    tabsList.value.scrollTo({
      top: 0,
      left: scrollPosition,
      behavior: 'smooth',
    });
  }
};

// Watch for changes in element sizes with immediate execution
watch(
  [containerWidth, listWidth],
  () => {
    computeScrollWidth();
  },
  { immediate: true }
);
</script>

<template>
  <div
    ref="tabsContainer"
    class="flex"
    :class="[
      border && !isPillVariant && 'border-b border-b-n-weak',
      isPillVariant &&
        'bg-[#F0F2F5] dark:bg-[#202326] rounded-[18px] px-1.5 py-1 shadow-sm',
    ]"
  >
    <button
      v-if="hasScroll"
      class="items-center rounded-none cursor-pointer flex h-auto justify-center min-w-8"
      @click="onScrollClick('left')"
    >
      <fluent-icon icon="chevron-left" :size="16" />
    </button>
    <ul
      ref="tabsList"
      class="border-r-0 border-l-0 border-t-0 flex min-w-[6.25rem] list-none mb-0"
      :class="
        [
          hasScroll ? 'overflow-hidden max-w-[calc(100%-64px)]' : '',
          !hasScroll && isPillVariant ? 'justify-center' : '',
          isPillVariant ? 'px-1 py-0.5 gap-1.5' : 'py-0 px-4',
        ].join(' ')
      "
    >
      <slot />
    </ul>
    <button
      v-if="hasScroll"
      class="items-center rounded-none cursor-pointer flex h-auto justify-center min-w-8"
      @click="onScrollClick('right')"
    >
      <fluent-icon icon="chevron-right" :size="16" />
    </button>
  </div>
</template>
