<script setup>
import { computed, inject } from 'vue';

const props = defineProps({
  index: {
    type: Number,
    default: 0,
  },
  name: {
    type: String,
    required: true,
  },
  disabled: {
    type: Boolean,
    default: false,
  },
  count: {
    type: Number,
    default: 0,
  },
  showBadge: {
    type: Boolean,
    default: true,
  },
  isCompact: {
    type: Boolean,
    default: false,
  },
  variant: {
    type: String,
    default: 'default',
  },
});

const activeIndex = inject('activeIndex');
const updateActiveIndex = inject('updateActiveIndex');
const shouldFitTabs = inject('shouldFitTabs', computed(() => false));

const active = computed(() => props.index === activeIndex.value);
const getItemCount = computed(() => props.count);
const isPillVariant = computed(() => props.variant === 'pill');

const onTabClick = event => {
  event.preventDefault();
  if (!props.disabled) {
    updateActiveIndex(props.index);
  }
};
</script>

<template>
  <li
    class="my-0 ltr:first:ml-0 rtl:first:mr-0 ltr:last:mr-0 rtl:last:ml-0 hover:text-n-slate-12"
    :class="[
      shouldFitTabs ? 'flex-1 min-w-0 mx-0' : 'flex-shrink-0',
      isPillVariant ? 'mx-0.5' : shouldFitTabs ? '' : 'mx-2',
    ]"
  >
    <a
      class="flex items-center flex-row select-none cursor-pointer relative transition-colors duration-[150ms] ease-[cubic-bezier(0.37,0,0.63,1)]"
      :class="[
        shouldFitTabs ? 'w-full justify-center' : '',
        isPillVariant
          ? active
            ? 'bg-[#4F6EF7] dark:bg-[#3B5BDB] text-white shadow-sm'
            : 'text-n-slate-12 dark:text-n-slate-11 hover:text-n-slate-12 hover:bg-n-alpha-2 dark:hover:bg-n-alpha-4'
          : active
            ? 'bg-n-alpha-2 dark:bg-n-alpha-4 text-n-blue-text'
            : 'text-n-slate-11 hover:bg-n-alpha-1 dark:hover:bg-n-alpha-3',
        isPillVariant
          ? 'rounded-full px-2 py-1.5 text-[13px] font-medium'
          : isCompact
            ? 'py-2 text-[13px] rounded-[5px] px-1'
            : 'text-[15px] py-3 rounded-[5px] px-1',
      ]"
      @click="onTabClick"
    >
      {{ name }}
      <div
        v-if="showBadge"
        class="flex items-center justify-center text-xxs font-semibold my-0 mx-0.5 px-0.5 py-0 min-w-[16px]"
        :class="[
          isPillVariant ? 'rounded-full h-5 px-1.5' : 'rounded-md h-5',
          active
            ? isPillVariant
              ? 'bg-white text-[#1F2937] dark:bg-[#1F2A37] dark:text-[#E5E7EB]'
              : 'bg-n-brand/10 dark:bg-n-brand/20 text-n-blue-text'
            : 'bg-n-alpha-2 dark:bg-n-alpha-4 text-n-slate-11',
        ]"
      >
        <span>
          {{ getItemCount }}
        </span>
      </div>
    </a>
  </li>
</template>
