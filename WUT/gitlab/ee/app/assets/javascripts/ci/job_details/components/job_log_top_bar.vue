<script>
// eslint-disable-next-line no-restricted-imports
import { mapState } from 'vuex';
import CeJobLogTopBar from '~/ci/job_details/components/job_log_top_bar.vue';

export default {
  components: {
    CeJobLogTopBar,
  },
  props: {
    size: {
      type: Number,
      required: true,
    },
    rawPath: {
      type: String,
      required: false,
      default: null,
    },
    isScrollTopDisabled: {
      type: Boolean,
      required: true,
    },
    isScrollBottomDisabled: {
      type: Boolean,
      required: true,
    },
    isScrollingDown: {
      type: Boolean,
      required: true,
    },
    isJobLogSizeVisible: {
      type: Boolean,
      required: true,
    },
    isComplete: {
      type: Boolean,
      required: true,
    },
    jobLog: {
      type: Array,
      required: true,
    },
    fullScreenModeAvailable: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullScreenEnabled: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState(['job']),
  },
  methods: {
    handleScrollTop() {
      this.$emit('scrollJobLogTop');
    },
    handleScrollBottom() {
      this.$emit('scrollJobLogBottom');
    },
    handleSearchResults(searchResults) {
      this.$emit('searchResults', searchResults);
    },
    handleFullscreen() {
      this.$emit('enterFullscreen');
    },
    handleExitFullscreen() {
      this.$emit('exitFullscreen');
    },
  },
};
</script>
<template>
  <div class="gl-contents">
    <ce-job-log-top-bar
      :size="size"
      :raw-path="rawPath"
      :is-scroll-top-disabled="isScrollTopDisabled"
      :is-scroll-bottom-disabled="isScrollBottomDisabled"
      :is-scrolling-down="isScrollingDown"
      :is-job-log-size-visible="isJobLogSizeVisible"
      :is-complete="isComplete"
      :job-log="jobLog"
      :full-screen-mode-available="fullScreenModeAvailable"
      :full-screen-enabled="fullScreenEnabled"
      v-bind="$attrs"
      @scrollJobLogTop="handleScrollTop"
      @scrollJobLogBottom="handleScrollBottom"
      @searchResults="handleSearchResults"
      @enterFullscreen="handleFullscreen"
      @exitFullscreen="handleExitFullscreen"
    />
  </div>
</template>
