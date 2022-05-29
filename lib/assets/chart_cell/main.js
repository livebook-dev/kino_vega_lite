import * as Vue from "https://cdn.jsdelivr.net/npm/vue@3.2.26/dist/vue.esm-browser.prod.js";

export function init(ctx, payload) {
  ctx.importCSS("main.css");
  ctx.importCSS(
    "https://fonts.googleapis.com/css2?family=Inter:wght@400;500&display=swap"
  );

  const app = Vue.createApp({
    template: `
      <div class="app">
        <!-- Info Messages -->
        <div id="info-box" class="info-box" v-if="missingDep">
          <p>To successfully build charts, you need to add the following dependency:</p>
          <span>{{ missingDep }}</span>
        </div>
        <div id="data-info-box" class="info-box" v-if="noDataVariable">
          <p>To successfully plot graphs, you need at least one dataset available.</p>
          <p>A dataset can be a map of series, for example:</p>
          <span>my_data = %{a: [89, 124, 09, 67, 45], b: [12, 45, 67, 83, 32]}</span>
          <p>Or Explorer dataframes:</p>
          <span>iris = Explorer.Datasets.iris()</span>
        </div>

        <!-- Chart Form -->
        <form @change="handleFieldChange">
        <div class="container">
          <div class="root">
            <BaseInput
              name="chart_title"
              label="Charting"
              type="text"
              placeholder="Title"
              v-model="rootFields.chart_title"
              class="input--md"
              :disabled="noDataVariable"
            />
            <BaseInput
              name="width"
              label="Width"
              type="number"
              v-model="rootFields.width"
              class="input--xs"
              :disabled="noDataVariable"
            />
            <BaseInput
              name="height"
              label="Height"
              type="number"
              v-model="rootFields.height"
              class="input--xs"
              :disabled="noDataVariable"
            />
          </div>
          <div class="layers" v-for="(layer, index) in layers">
            <div class="row">
              <BaseSelect
                name="data_variable"
                label="Data"
                :layer="index"
                v-model="layer.data_variable"
                :options="dataVariables"
                :required
                :disabled="noDataVariable"
              />
              <BaseSelect
                name="chart_type"
                label="Chart"
                :layer="index"
                v-model="layer.chart_type"
                :options="chartOptions"
                :required
                :disabled="noDataVariable"
              />
              <div class="field"></div>
            </div>
            <div class="row">
              <BaseSelect
                name="x_field"
                label="x-axis"
                :layer="index"
                v-model="layer.x_field"
                :options="axisOptions(layer)"

                :disabled="noDataVariable"
              />
              <BaseSelect
                name="x_field_type"
                label="Type"
                :layer="index"
                v-model="layer.x_field_type"
                :options="typeOptions"
                :disabled="noXField(layer)"
              />
              <BaseSelect
                name="x_field_aggregate"
                label="Aggregate"
                :layer="index"
                v-model="layer.x_field_aggregate"
                :options="aggregateOptions"
                :disabled="noXField(layer)"
              />
            </div>
            <div class="row">
              <BaseSelect
                name="y_field"
                label="y-axis"
                :layer="index"
                v-model="layer.y_field"
                :options="axisOptions(layer)"
                :disabled="noDataVariable"
              />
              <BaseSelect
                name="y_field_type"
                label="Type"
                :layer="index"
                v-model="layer.y_field_type"
                :options="typeOptions"
                :disabled="noYField(layer)"
              />
              <BaseSelect
                name="y_field_aggregate"
                label="Aggregate"
                :layer="index"
                v-model="layer.y_field_aggregate"
                :options="aggregateOptions"
                :disabled="noYField(layer)"
              />
            </div>
            <div class="row">
              <BaseSelect
                name="color_field"
                label="Color"
                :layer="index"
                v-model="layer.color_field"
                :options="axisOptions(layer)"
                :disabled="noDataVariable"
              />
              <BaseSelect
                name="color_field_type"
                label="Type"
                :layer="index"
                v-model="layer.color_field_type"
                :options="typeOptions"
                :disabled="noColorField(layer)"
              />
              <BaseSelect
                name="color_field_aggregate"
                label="Aggregate"
                :layer="index"
                v-model="layer.color_field_aggregate"
                :options="aggregateOptions"
                :disabled="noColorField(layer)"
              />
            </div>
            <!-- Add/Remove Layer -->
            <div class="controls">
              <button v-if="isLastLayer(index)" :disabled="noDataVariable" class="button blue" type="button"
              @click="addLayer">Add layer</button>
              <button v-if="hasLayers" class="button red" type="button"
              @click="removeLayer(index)">Remove layer</button>
            </div>
          </div>
        </div>
        </form>
      </div>
    `,

    data() {
      return {
        rootFields: payload.root_fields,
        layers: payload.layers,
        dataOptions: payload.data_options,
        missingDep: payload.missing_dep,
        chartOptions: ["point", "bar", "line", "area", "boxplot", "rule"],
        typeOptions: ["quantitative", "nominal", "ordinal", "temporal"],
        aggregateOptions: ["sum", "mean"],
        dataVariables: payload.data_options.map((data) => data["variable"]),
      };
    },

    computed: {
      noDataVariable() {
        return !this.layers[0].data_variable;
      },
      hasLayers() {
        return this.layers.length > 1;
      },
    },

    methods: {
      axisOptions(layer) {
        const dataVariable = layer.data_variable;
        const dataOptions = this.dataOptions.find(
          (data) => data["variable"] === dataVariable
        );
        return dataOptions ? dataOptions["columns"].concat("__count__") : [];
      },
      noColorField(layer) {
        return !layer.color_field || layer.color_field === "__count__";
      },
      noYField(layer) {
        return !layer.y_field || layer.y_field === "__count__";
      },
      noXField(layer) {
        return !layer.x_field || layer.x_field === "__count__";
      },
      isLastLayer(idx) {
        return this.layers.length === idx + 1;
      },
      handleFieldChange(event) {
        const { name, value } = event.target;
        const layer = event.target.getAttribute("layer");
        ctx.pushEvent("update_field", { field: name, value, layer });
      },
      addLayer() {
        ctx.pushEvent("add_layer");
      },
      removeLayer(idx) {
        ctx.pushEvent("remove_layer", { layer: idx });
      },
    },

    components: {
      BaseInput: {
        props: {
          label: {
            type: String,
            default: "",
          },
          modelValue: {
            type: [String, Number],
            default: "",
          },
        },
        template: `
          <div class="root-field">
            <label class="input-label">{{ label }}</label>
            <input
              :value="modelValue"
              @input="$emit('update:modelValue', $event.target.value)"
              v-bind="$attrs"
              class="input"
            >
          </div>
        `,
      },
      BaseSelect: {
        props: {
          label: {
            type: String,
            default: "",
          },
          modelValue: {
            type: [String, Number],
            default: "",
          },
          options: {
            type: Array,
            default: [],
            required: true,
          },
          required: {
            type: Boolean,
            default: false,
          },
        },
        methods: {
          available(value, options) {
            return value ? options.includes(value) : true;
          },
          optionLabel(value) {
            return value === "__count__" ? "COUNT(*)" : value;
          },
        },
        template: `
          <div class="field">
            <label class="input-label">{{ label }}</label>
            <select
              :value="modelValue"
              v-bind="$attrs"
              @change="$emit('update:modelValue', $event.target.value)"
              class="input"
              :class="{ unavailable: !available(modelValue, options) }"
            >
              <option v-if="!required && available(modelValue, options)"></option>
              <option
                v-for="option in options"
                :value="option"
                :key="option"
                :selected="option === modelValue"
              >{{ optionLabel(option) }}</option>
              <option
                v-if="!available(modelValue, options)"
                class="unavailable-option"
                :value="modelValue"
              >{{ optionLabel(modelValue) }}</option>
            </select>
          </div>
        `,
      },
    },
  }).mount(ctx.root);

  ctx.handleEvent("update_root", ({ fields }) => {
    setRootValues(fields);
  });

  ctx.handleEvent("update_layer", ({ idx, fields }) => {
    setLayerValues(idx, fields);
  });

  ctx.handleEvent("set_layers", ({ layers }) => {
    app.layers = layers;
  });

  ctx.handleEvent("missing_dep", ({ dep }) => {
    app.missingDep = dep;
  });

  ctx.handleEvent("set_available_data", ({ data_options, fields }) => {
    app.dataVariables = data_options.map((data) => data["variable"]);
    app.dataOptions = data_options;
    setLayerValues(0, fields);
  });

  ctx.handleSync(() => {
    // Synchronously invokes change listeners
    document.activeElement &&
      document.activeElement.dispatchEvent(
        new Event("change", { bubbles: true })
      );
  });

  function setRootValues(fields) {
    for (const field in fields) {
      app.rootFields[field] = fields[field];
    }
  }

  function setLayerValues(idx, fields) {
    for (const field in fields) {
      app.layers[idx][field] = fields[field];
    }
  }
}
