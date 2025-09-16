import Vue from 'vue';
import VueRouter from 'vue-router';
import { initSimpleApp } from '~/helpers/init_simple_app_helper';
import { EditMlModelVersion } from '~/ml/model_registry/apps';

Vue.use(VueRouter);

initSimpleApp('#js-mount-edit-ml-model-version', EditMlModelVersion, {
  withApolloProvider: true,
  name: 'EditMlModelVersion',
});
