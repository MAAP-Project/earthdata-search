#= require models/data/granules
#= require models/data/service_options
#= require models/data/data_quality_summaries

ns = @edsc.models.data

ns.Dataset = do (ko
                 KnockoutModel = @edsc.models.KnockoutModel
                 Granules=ns.Granules
                 QueryModel = ns.Query
                 ServiceOptionsModel = ns.ServiceOptions
                 DataQualitySummaryModel = ns.DataQualitySummary
                 toParam=jQuery.param
                 extend=jQuery.extend
                 ) ->

  datasets = ko.observableArray()

  randomKey = Math.random()

  register = (dataset) ->
    dataset.reference()
    datasets.push(dataset)
    subscription = dataset.refCount.subscribe (count) ->
      if count <= 0
        datasets.remove(dataset)
        subscription.dispose()

    dataset

  class Dataset extends KnockoutModel
    @findOrCreate: (jsonData, query) ->
      id = jsonData.id
      for dataset in datasets()
        return dataset.reference() if dataset.id.peek() == id
      register(new Dataset(jsonData, query, randomKey))

    @visible: ko.computed
      read: -> dataset for dataset in datasets() when dataset.visible()

    constructor: (jsonData, @query, inKey) ->
      throw "Datasets should not be constructed directly" unless inKey == randomKey

      @granuleQuery = @disposable(new QueryModel('echo_collection_id': jsonData.id))
      @granuleQuery.sortKey(['-start_date'])
      @granulesModel = granulesModel = @disposable(new Granules(@granuleQuery, @query))
      @granuleAccessOptions = @asyncComputed({}, 100, @_loadGranuleAccessOptions, this)

      @visible = ko.observable(false)

      @serviceOptions = @disposable(new ServiceOptionsModel(@granuleAccessOptions))

      @fromJson(jsonData)

      # TODO: Is this needed?
      @error = ko.observable(null)
      @spatial_constraint = @computed =>
        if @points?
          'point:' + @points()[0].split(/\s+/).reverse().join(',')
        else
          null

      @granuleDownloadsUrl = @computed
        read: =>
          params = @query.params()
          paramStr = toParam(extend(@_granuleParams(params), online_only: true, page_size: 2000))
          "/granules/download.html?#{paramStr}"
        deferEvaluation: true

      @granuleScriptUrl = @computed
        read: =>
          params = @query.params()
          paramStr = toParam(@_granuleParams(params))
          "/data/download.sh?#{paramStr}"
        deferEvaluation: true

      @dqsModel = @disposable(new DataQualitySummaryModel(new QueryModel('catalog_item_id': jsonData.id)))

    # A granules model not directly connected to the dataset model so classes can, e.g. query
    # for granules under a point without messing with displayed hits or timing values
    createGranulesModel: ->
      granuleQuery = new QueryModel('echo_collection_id': @id())
      granuleQuery.sortKey(['-start_date'])
      new Granules(granuleQuery, @query)

    _loadGranuleAccessOptions: (current, callback) ->
      params = @query.params()
      downloadableParams = extend(@_granuleParams(params), online_only: true, page_size: 2000)
      granulesModel = @createGranulesModel()
      granulesModel.search @_granuleParams(params), =>
        hits = granulesModel.hits()
        granulesModel.dispose()

        downloadableModel = @createGranulesModel()
        downloadableModel.search downloadableParams, (results) =>
          downloadableHits = downloadableModel.hits()

          sizeMB = 0
          sizeMB += parseFloat(granule.granule_size) for granule in results
          size = sizeMB * 1024 * 1024

          units = ['', 'Kilo', 'Mega', 'Giga', 'Tera', 'Peta', 'Exa']
          while size > 1000 && units.length > 1
            size = size / 1000
            units.shift()

          size = Math.round(size * 10) / 10
          size = "> #{size}" if hits > 2000

          downloadableModel.dispose()

          options =
            count: hits
            size: size
            sizeUnit: "#{units[0]}bytes"
            canDownloadAll: hits == downloadableHits
            canDownload: downloadableHits > 0
            downloadCount: downloadableHits
            accessMethod: null
          callback(options)

    _granuleParams: (params) ->
      extend({}, params, 'echo_collection_id[]': @id(), @granuleQuery.params())

    granuleFiltersApplied: ->
      # granuleQuery.params() will have echo_collection_id and page_size by default
      params = @granuleQuery.params()
      ignored_params = ['page_size', 'page_num', 'sort_key', 'echo_collection_id']
      for own key, value of params
        return true if ignored_params.indexOf(key) == -1
      return false

    serialize: ->
      result = {id: @id(), dataset_id: @dataset_id(), has_granules: @has_granules()}
      if @has_granules()
        result.params = @granuleQuery.serialize()
        if @granuleAccessOptions.isSetup()
          result.granuleAccessOptions = @granuleAccessOptions()
      result.serviceOptions = @serviceOptions.serialize()
      result

    fromJson: (jsonObj) ->
      jsonObj = extend({}, jsonObj)

      @granuleQuery.fromJson(jsonObj.params) if jsonObj.params?
      @granuleAccessOptions(jsonObj.granuleAccessOptions) if jsonObj.granuleAccessOptions?
      @serviceOptions.fromJson(jsonObj.serviceOptions) if jsonObj.serviceOptions?

      delete jsonObj.params
      delete jsonObj.granuleAccessOptions
      delete jsonObj.serviceOptions

      @json = jsonObj

      @thumbnail = ko.observable(null)
      @archive_center = ko.observable(null)
      ko.mapping.fromJS(jsonObj, {}, this)
      if @gibs
        @gibs = ko.observable(ko.mapping.toJS(@gibs))
      else
        @gibs = ko.observable(null)