export async function init(ctx, payload) {
  await importJS(
    "https://cdn.jsdelivr.net/npm/vue@3.2.37/dist/vue.global.prod.js"
  );
  await importJS(
    "https://cdn.jsdelivr.net/npm/vue-dndrop@1.2.13/dist/vue-dndrop.min.js"
  );
  ctx.importCSS("main.css");
  ctx.importCSS(
    "https://fonts.googleapis.com/css2?family=Inter:wght@400;500&display=swap"
  );

  const BaseInput = {
    props: {
      label: {
        type: String,
        default: "",
      },
      modelValue: {
        type: [String, Number],
        default: "",
      },
      inputClass: {
        type: String,
        default: "",
      },
      fieldClass: {
        type: String,
        default: "root-field",
      },
      inner: {
        type: Boolean,
        default: false,
      },
    },
    template: `
        <div :class="[inner ? 'inner-field' : fieldClass]">
          <label class="input-label">{{ label }}</label>
          <input
            :value="modelValue"
            @input="$emit('update:modelValue', $event.target.value)"
            v-bind="$attrs"
            :class="['input', inputClass]"
          >
        </div>
      `,
  };

  const BaseSelect = {
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
      selectClass: {
        type: String,
        default: "",
      },
      fieldClass: {
        type: String,
        default: "field",
      },
      inner: {
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
        <div :class="[inner ? 'inner-field' : fieldClass]">
          <label class="input-label">{{ label }}</label>
          <select
            :value="modelValue"
            v-bind="$attrs"
            @change="$emit('update:modelValue', $event.target.value)"
            class="input"
            :class="[selectClass, { unavailable: !available(modelValue, options) }]"
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
  };

  const BaseSwitch = {
    props: {
      label: {
        type: String,
        default: "",
      },
      modelValue: {
        type: Boolean,
      },
      fieldClass: {
        type: String,
        default: "field",
      },
      inner: {
        type: Boolean,
        default: false,
      },
    },
    template: `
        <div :class="[inner ? 'inner-field' : fieldClass]">
          <label class="input-label"> {{ label }} </label>
          <div class="input-container">
            <label class="switch-button">
              <input
                :checked="modelValue"
                type="checkbox"
                @input="$emit('update:modelValue', $event.target.checked)"
                v-bind="$attrs"
                class="switch-button-checkbox"
              >
              <div class="switch-button-bg" />
            </label>
          </div>
        </div>
      `,
  };

  const Accordion = {
    data() {
      return {
        isOpen: payload.layers.length <= 2,
      };
    },
    props: {
      hasLayers: {
        type: Boolean,
        required: true,
      },
      hasOnlyGeoLayers: {
        type: Boolean,
        required: true,
      },
      isGeoLayer: {
        type: Boolean,
        required: false,
      },
    },
    methods: {
      toggleAccordion() {
        this.isOpen = !this.isOpen;
      },
    },
    template: `
        <div class="layer-wrapper" :class="{'card': hasLayers}">
          <div
            class="accordion-control"
            :class="{'expanded': isOpen}"
            :aria-expanded="isOpen"
            :aria-controls="id"
            v-show="hasLayers"
          >
            <span>
              <button
                class="button button--toggle"
                @click="toggleAccordion()"
                type="button"
              >
                <svg
                  class="button-svg"
                  :class="{
                    'rotate-0': isOpen,
                    'rotate--90': !isOpen,
                  }"
                  fill="currentColor"
                  stroke="currentColor"
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 16 10"
                  aria-hidden="true"
                >
                  <path
                    d="M15 1.2l-7 7-7-7"
                  />
                </svg>

                <slot name="title" /><slot name="subtitle" v-if="!isOpen"/>
              </button>
            </span>
            <span></span>
            <div class="layer-controls">
              <slot name="toggle" />
              <button
                class="button button--sm"
                @click="$emit('removeLayer')"
                type="button"
                v-show="(hasLayers && !hasOnlyGeoLayers) || isGeoLayer"
              >
                <svg
                  class="button-svg"
                  fill="currentColor"
                  stroke="none"
                  xmlns="http://www.w3.org/2000/svg"
                  viewBox="0 0 16 16"
                  aria-hidden="true"
                >
                  <path
                    d="M11.75 3.5H15.5V5H14V14.75C14 14.9489 13.921 15.1397 13.7803 15.2803C13.6397 15.421 13.4489
                    15.5 13.25 15.5H2.75C2.55109 15.5 2.36032 15.421 2.21967 15.2803C2.07902 15.1397 2 14.9489 2
                    14.75V5H0.5V3.5H4.25V1.25C4.25 1.05109 4.32902 0.860322 4.46967 0.71967C4.61032 0.579018 4.80109
                    0.5 5 0.5H11C11.1989 0.5 11.3897 0.579018 11.5303 0.71967C11.671 0.860322 11.75 1.05109 11.75
                    1.25V3.5ZM12.5 5H3.5V14H12.5V5ZM5.75 7.25H7.25V11.75H5.75V7.25ZM8.75
                    7.25H10.25V11.75H8.75V7.25ZM5.75 2V3.5H10.25V2H5.75Z"
                  />
                </svg>
              </button>
            </div>
          </div>
          <div class="accordion-body" v-show="isOpen || !hasLayers">
            <slot name="content" />
          </div>
        </div>
      `,
  };

  const FieldSettings = {
    data() {
      return {
        isOpen: false,
      };
    },
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
    methods: {
      toggleSettings() {
        this.isOpen = !this.isOpen;
      },
    },
    template: `
        <div class="icon-container" @click="toggleSettings()">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">
            <path fill="none" d="M0 0h24v24H0z"/>
            <path d="M3.34 17a10.018 10.018 0 0 1-.978-2.326 3 3 0 0 0 .002-5.347A9.99 9.99 0 0 1 4.865 4.99a3 3 0 0 0
            4.631-2.674 9.99 9.99 0 0 1 5.007.002 3 3 0 0 0 4.632 2.672c.579.59 1.093 1.261 1.525 2.01.433.749.757
            1.53.978 2.326a3 3 0 0 0-.002 5.347 9.99 9.99 0 0 1-2.501 4.337 3 3 0 0 0-4.631 2.674 9.99 9.99 0 0
            1-5.007-.002 3 3 0 0 0-4.632-2.672A10.018 10.018 0 0 1 3.34 17zm5.66.196a4.993 4.993 0 0 1 2.25
            2.77c.499.047 1 .048 1.499.001A4.993 4.993 0 0 1 15 17.197a4.993 4.993 0 0 1
            3.525-.565c.29-.408.54-.843.748-1.298A4.993 4.993 0 0 1 18 12c0-1.26.47-2.437 1.273-3.334a8.126 8.126 0 0
            0-.75-1.298A4.993 4.993 0 0 1 15 6.804a4.993 4.993 0 0 1-2.25-2.77c-.499-.047-1-.048-1.499-.001A4.993 4.993
            0 0 1 9 6.803a4.993 4.993 0 0 1-3.525.565 7.99 7.99 0 0 0-.748 1.298A4.993 4.993 0 0 1 6 12c0 1.26-.47
            2.437-1.273 3.334a8.126 8.126 0 0 0 .75 1.298A4.993 4.993 0 0 1 9 17.196zM12 15a3 3 0 1 1 0-6 3 3 0 0 1 0
            6zm0-2a1 1 0 1 0 0-2 1 1 0 0 0 0 2z" fill="#000"/>
          </svg>
        </div>
        <div class="field-settings-container" v-if="isOpen">
          <slot name="content" />
        </div>
      `,
  };

  const app = Vue.createApp({
    components: {
      BaseSelect,
      BaseInput,
      BaseSwitch,
      Accordion,
      FieldSettings,
      Container: VueDndrop.Container,
      Draggable: VueDndrop.Draggable,
    },
    template: `
      <div class="app">
        <!-- Info Messages -->
        <div class="box box-warning" v-if="missingDep">
          <p>To successfully build charts, you need to add the following dependency:</p>
          <pre><code>{{ missingDep }}</code></pre>
        </div>
        <div class="box box-warning" v-if="noDataVariable">
          <p>To successfully plot graphs, you need at least one dataset available.</p>
          <p>A dataset can be a map of series, for example:</p>
          <pre><code>my_data = %{a: [89, 124, 0, 67, 45], b: [12, 45, 67, 83, 31]}</code></pre>
          <p>Or an <a href="https://github.com/elixir-nx/explorer" target="_blank">Explorer</a> dataframe:</p>
          <pre><code>iris = Explorer.Datasets.iris()</code></pre>
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
          <div class="layers">
            <Container @drop="handleItemDrop" lock-axis="y" non-drag-area-selector=".accordion-body">
              <Draggable v-for="(layer, index) in layers" :drag-not-allowed="layer.chart_type === 'geoshape'">
                <Accordion
                  @remove-layer="removeLayer(index)"
                  :hasLayers="hasLayers"
                  :hasOnlyGeoLayers="hasOnlyGeoLayers"
                  :isGeoLayer="(isGeoLayer(index))"
                >
                  <template v-slot:title>
                    <span>
                      Layer {{ index + 1 }}
                    </span>
                  </template>
                  <template v-slot:subtitle><span>: {{ layer.chart_type }} for {{ layer.data_variable }}</span></template>
                  <template v-slot:toggle>
                    <BaseSwitch
                      name="active"
                      :layer="index"
                      v-model="layer.active"
                      :disabled="noDataVariable"
                      fieldClass="switch-sm"
                    />
                  </template>
                  <template v-slot:content>
                    <div class="row" v-if="layer.chart_type !== 'geoshape'">
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
                    <div class="row" v-else>
                      <BaseInput
                        name="geodata_url"
                        label="Geodata URL"
                        placeholder="Geodata from url"
                        :layer="index"
                        v-model="layer.geodata_url"
                        :required
                        :disabled="noDataVariable"
                        fieldClass="field field--xl"
                      />
                      <BaseInput
                        name="projection_center"
                        label="Projection Center"
                        placeholder="Projection center"
                        :layer="index"
                        v-model="layer.projection_center"
                        :required
                        :disabled="noDataVariable"
                        fieldClass="field"
                      />
                    </div>
                    <div class="row" v-if="layer.chart_type !== 'geoshape'">
                      <BaseSelect
                        v-if="isGeoData(index)"
                        name="latitude_field"
                        label="Latitude"
                        :layer="index"
                        v-model="layer.latitude_field"
                        :options="axisOptions(layer)"
                        :disabled="noDataVariable"
                      />
                      <div class="input-icon-container" v-else>
                        <BaseSelect
                          name="x_field"
                          label="x-axis"
                          :layer="index"
                          v-model="layer.x_field"
                          :options="axisOptions(layer)"
                          :disabled="noDataVariable"
                          selectClass="input-icon"
                          fieldClass="field-with-settings"
                        />
                        <FieldSettings v-if="layer.x_field">
                          <template v-slot:content>
                            <BaseSelect
                              name="x_field_type"
                              label="Type"
                              :layer="index"
                              v-model="layer.x_field_type"
                              :options="typeOptions"
                              :disabled="!hasDataField(layer.x_field)"
                              :inner
                            />
                            <BaseSelect
                              name="x_field_aggregate"
                              label="Aggregate"
                              :layer="index"
                              v-model="layer.x_field_aggregate"
                              :options="aggregateOptions"
                              :disabled="!hasDataField(layer.x_field)"
                              :inner
                            />
                            <BaseSelect
                              name="x_field_scale_type"
                              label="Scale"
                              :layer="index"
                              v-model="layer.x_field_scale_type"
                              :options="scaleOptions"
                              :disabled="!hasDataField(layer.x_field)"
                              :inner
                            />
                            <BaseInput
                              name="x_field_bin"
                              label="Bins"
                              type="number"
                              :layer="index"
                              v-model="layer.x_field_bin"
                              :disabled="!hasDataField(layer.x_field)"
                              :inner
                              class="inner-number-input"
                            />
                          </template>
                        <FieldSettings/>
                      </div>
                      <BaseSelect
                        v-if="isGeoData(index)"
                        name="longitude_field"
                        label="Longitude"
                        :layer="index"
                        v-model="layer.longitude_field"
                        :options="axisOptions(layer)"
                        :disabled="noDataVariable"
                      />
                      <div class="input-icon-container" v-else>
                        <BaseSelect
                          name="y_field"
                          label="y-axis"
                          :layer="index"
                          v-model="layer.y_field"
                          :options="axisOptions(layer)"
                          :disabled="noDataVariable"
                          selectClass="input-icon"
                          fieldClass="field-with-settings"
                        />
                        <FieldSettings v-if="layer.y_field">
                          <template v-slot:content>
                            <BaseSelect
                              name="y_field_type"
                              label="Type"
                              :layer="index"
                              v-model="layer.y_field_type"
                              :options="typeOptions"
                              :disabled="!hasDataField(layer.y_field)"
                              :inner
                            />
                            <BaseSelect
                              name="y_field_aggregate"
                              label="Aggregate"
                              :layer="index"
                              v-model="layer.y_field_aggregate"
                              :options="aggregateOptions"
                              :disabled="!hasDataField(layer.y_field)"
                              :inner
                            />
                            <BaseSelect
                              name="y_field_scale_type"
                              label="Scale"
                              :layer="index"
                              v-model="layer.y_field_scale_type"
                              :options="scaleOptions"
                              :disabled="!hasDataField(layer.y_field)"
                              :inner
                            />
                            <BaseInput
                              name="y_field_bin"
                              label="Bins"
                              type="number"
                              :layer="index"
                              v-model="layer.y_field_bin"
                              :inner
                              :disabled="!hasDataField(layer.y_field)"
                              :inner
                              class="inner-number-input"
                            />
                          </template>
                        <FieldSettings/>
                      </div>
                      <div class="input-icon-container" v-if="!isGeoData(index)">
                        <BaseSelect
                          name="color_field"
                          label="Color"
                          :layer="index"
                          v-model="layer.color_field"
                          :options="axisOptions(layer)"
                          :disabled="noDataVariable"
                          selectClass="input-icon"
                          fieldClass="field-with-settings"
                        />
                        <FieldSettings v-if="layer.color_field">
                          <template v-slot:content>
                            <BaseSelect
                              name="color_field_type"
                              label="Type"
                              :layer="index"
                              v-model="layer.color_field_type"
                              :options="typeOptions"
                              :disabled="!hasDataField(layer.color_field)"
                              :inner
                            />
                            <BaseSelect
                              name="color_field_aggregate"
                              label="Aggregate"
                              :layer="index"
                              v-model="layer.color_field_aggregate"
                              :options="aggregateOptions"
                              :disabled="!hasDataField(layer.color_field)"
                              :inner
                            />
                            <BaseSelect
                              name="color_field_scale_scheme"
                              label="Scheme"
                              :layer="index"
                              v-model="layer.color_field_scale_scheme"
                              :options="colorSchemeOptions"
                              :disabled="!hasDataField(layer.color_field)"
                              :inner
                            />
                            <BaseInput
                              name="color_field_bin"
                              label="Bins"
                              type="number"
                              :layer="index"
                              v-model="layer.color_field_bin"
                              :inner
                              :disabled="!hasDataField(layer.color_field)"
                              :inner
                              class="inner-number-input"
                            />
                          </template>
                        <FieldSettings/>
                      </div>
                      <BaseSelect
                        v-else
                        name="geodata_color"
                        label="Color"
                        :layer="index"
                        v-model="layer.geodata_color"
                        :options="colorsOptions"
                        :disabled="noDataVariable"
                        :required
                      />
                    </div>
                    <div class="row" v-else">
                      <BaseSelect
                        name="geodata_type"
                        label="Geodata Type"
                        :layer="index"
                        v-model="layer.geodata_type"
                        :options="geoShapeOptions"
                        :required
                        :disabled="noDataVariable"
                      />
                      <BaseSelect
                        name="projection_type"
                        label="Projection Type"
                        :layer="index"
                        v-model="layer.projection_type"
                        :options="projectionOptions"
                        :required
                        :disabled="noDataVariable"
                      />
                      <BaseInput
                        name="geodata_feature"
                        label="Feature"
                        placeholder="Feature"
                        :layer="index"
                        v-model="layer.geodata_feature"
                        :required
                        :disabled="noDataVariable"
                        fieldClass="field"
                      />
                    </div>
                  </template>
                </Accordion>
              </Draggable>
            </Container>
          </div>
          <div class="add-layer">
            <button class="button button--dashed" type="button" :disabled="unavailableDataVariable" @click="addLayer()">
              <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                <path d="M4.41699 4.41602V0.916016H5.58366V4.41602H9.08366V5.58268H5.58366V9.08268H4.41699V5.58268H0.916992V4.41602H4.41699Z"/>
              </svg>
              Layer
            </button>
            <button class="button button--dashed" type="button" :disabled="hasGeoLayer || unavailableDataVariable" @click="addGeoLayer()">
              <svg width="10" height="10" viewBox="0 0 10 10" fill="currentColor" xmlns="http://www.w3.org/2000/svg">
                <path d="M4.41699 4.41602V0.916016H5.58366V4.41602H9.08366V5.58268H5.58366V9.08268H4.41699V5.58268H0.916992V4.41602H4.41699Z"/>
              </svg>
              Geodata
            </button>
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
        chartOptions: [
          "point",
          "bar",
          "line",
          "area",
          "boxplot",
          "rule",
          "point (geodata)",
          "circle (geodata)",
          "square (geodata)",
        ],
        typeOptions: ["quantitative", "nominal", "ordinal", "temporal"],
        projectionOptions: ["mercator"],
        geoShapeOptions: ["geojson", "topojson"],
        aggregateOptions: ["sum", "mean"],
        scaleOptions: ["linear", "pow", "sqrt", "symlog", "log", "time", "utc"],
        colorsOptions: ["blue", "red", "green", "purple", "black", "brown"],
        colorSchemeOptions: [
          "accent",
          "category10",
          "dark2",
          "paired",
          "pastel1",
        ],
        dataVariables: payload.data_options.map((data) => data["variable"]),
      };
    },

    computed: {
      noDataVariable() {
        return !this.layers[0].data_variable;
      },
      hasOnlyGeoLayers() {
        return this.layers.length === 2 && this.isGeoLayer(0);
      },
      hasLayers() {
        return this.layers.length > 1;
      },
      unavailableDataVariable() {
        return !this.dataVariables.includes(this.layers[0].data_variable);
      },
      hasGeoLayer() {
        return this.layers.some((layer) => layer.chart_type === "geoshape");
      },
    },

    methods: {
      axisOptions(layer) {
        const dataVariable = layer.data_variable;
        const dataOptions = this.dataOptions.find(
          (data) => data["variable"] === dataVariable
        );
        return dataOptions
          ? dataOptions.columns.map((column) => column.name).concat("__count__")
          : [];
      },
      hasDataField(field) {
        return !!field && field !== "__count__";
      },
      isLastLayer(idx) {
        return this.layers.length === idx + 1;
      },
      isGeoLayer(idx) {
        return this.layers[idx].chart_type === "geoshape";
      },
      isGeoData(idx) {
        const geoDataMarks = [
          "point (geodata)",
          "circle (geodata)",
          "square (geodata)",
        ];
        return geoDataMarks.includes(this.layers[idx].chart_type);
      },
      handleFieldChange(event) {
        const field = event.target.name;
        const layer = event.target.getAttribute("layer");
        const value = layer
          ? this.layers[layer][field]
          : this.rootFields[field];
        ctx.pushEvent("update_field", {
          field,
          value,
          layer: layer && parseInt(layer),
        });
      },
      addLayer() {
        ctx.pushEvent("add_layer");
      },
      addGeoLayer() {
        ctx.pushEvent("add_geo_layer");
      },
      removeLayer(idx) {
        ctx.pushEvent("remove_layer", { layer: idx });
      },
      handleItemDrop({ removedIndex, addedIndex }) {
        const minAllowed = this.hasGeoLayer ? 1 : 0;
        addedIndex = Math.max(addedIndex, minAllowed);
        if (removedIndex === addedIndex) return;
        ctx.pushEvent("move_layer", { removedIndex, addedIndex });
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

// Imports a JS script globally using a <script> tag
function importJS(url) {
  return new Promise((resolve, reject) => {
    const scriptEl = document.createElement("script");
    scriptEl.addEventListener(
      "load",
      (event) => {
        resolve();
      },
      { once: true }
    );
    scriptEl.src = url;
    document.head.appendChild(scriptEl);
  });
}
