#= require models/data/query
#= require models/data/datasets
#= require models/data/dataset_facets
#= require models/data/project
#= require models/ui/spatial_type
#= require models/ui/temporal
#= require models/ui/datasets_list
#= require models/ui/project_list

models = @edsc.models
data = models.data
ui = models.ui

ns = models.page

ns.SearchPage = do (ko,
                    QueryModel = data.Query,
                    DatasetsModel = data.Datasets
                    DatasetFacetsModel = data.DatasetFacets
                    ProjectModel = data.Project
                    SpatialTypeModel = ui.SpatialType
                    TemporalModel = ui.Temporal
                    DatasetsListModel = ui.DatasetsList
                    ProjectListModel = ui.ProjectList) ->

  class SearchPage
    constructor: ->
      @query = new QueryModel()
      @datasets = new DatasetsModel()
      @datasetFacets = new DatasetFacetsModel(@query)
      @project = new ProjectModel(@query)

      @ui =
        spatialType: new SpatialTypeModel()
        temporal: new TemporalModel(@query)
        datasetsList: new DatasetsListModel(@query, @datasets)
        projectList: new ProjectListModel(@project, @datasets)
        isLandingPage: ko.observable(null) # Used by modules/landing

      @bindingsLoaded = ko.observable(false)

      @spatialError = ko.computed(@_computeSpatialError)

      ko.computed(@_computeDatasetResults).extend(throttle: 100)
      ko.computed(@_computeDatasetFacetsResults).extend(throttle: 100)

    pluralize: (value, singular, plural) ->
      word = if value == 1 then singular else plural
      "#{value} #{word}"

    _computeDatasetResults: =>
      @datasets.search(@query.params())

    _computeDatasetFacetsResults: =>
      @datasetFacets.search(@query.params())

    _computeSpatialError: =>
      error = @datasets.error()
      if error?
        return "Polygon boundaries must not cross themselves" if error.indexOf('ORA-13349') != -1
        return "Polygon is too large" if error.indexOf('ORA-13367') != -1
        return error if error.indexOf('ORA-') != -1
      null

  exports = SearchPage