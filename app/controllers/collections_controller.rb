class CollectionsController < ApplicationController
  respond_to :json

  around_action :log_execution_time

  UNLOGGED_PARAMS = %w(
    include_facets
    hierarchical_facets
    include_tags
    include_granule_counts
  ).freeze

  def index
    collection_params = collection_params_for_request(request)
    unless params['echo_collection_id']
      metrics_event('search', collection_params.except(*UNLOGGED_PARAMS).merge(user_id: session[:user_id]))
    end
    catalog_response = echo_client.get_collections(collection_params, token)

    if catalog_response.success?
      catalog_response.body['feed']['facets'] = {} if catalog_response.body['feed']['facets'].nil?
      catalog_response.body['feed']['facets']['children'] = add_fake_json_facets(catalog_response.body['feed']['facets'])

      CollectionExtra.decorate_all(catalog_response.body['feed']['entry'])

      catalog_response.headers.each do |key, value|
        response.headers[key] = value if key.start_with?('cmr-')
      end
    end

    respond_with(catalog_response.body, status: catalog_response.status)
  end

  def show
    metrics_event('details', collections: [params[:id]])

    response = echo_client.get_collection(params[:id], token, 'umm_json')

    if response.success?
      respond_with(CollectionDetailsPresenterUmmJson.new(response.body, params[:id], token, cmr_env), status: response.status)
    else
      respond_with(response.body, status: response.status)
    end
  end

  def use
    metrics_event('view', collections: [params[:id]])

    render json: result, status: :ok
  end

  def collection_relevancy
    number_of_collections = 20

    data = {
      query: params[:query],
      collections: params[:collections][0..number_of_collections - 1],
      selected_index: params[:selected_index],
      selected_collection: params[:selected_collection],
      exact_match: params[:exact_match]
    }

    metrics_event('collection_relevancy', data)
    render json: 'ok', status: :ok
  end

  private

  def collection_params_for_request(request)
    params = request.query_parameters.dup

    params.delete(:portal)
    if portal? && portal[:params]
      params.deep_merge!(portal[:params]) do |_key, v1, v2|
        if v1.is_a?(Array) && v2.is_a?(Array)
          v1 + v2
        else
          v2
        end
      end
    end

    test_facets = params.delete(:test_facets)

    params = params.except('include_facets') if Rails.env.test? && !test_facets

    features = Hash[Array.wrap(params.delete(:features)).map { |f| [f, true] }]
    if features['Customizable']
      params['tag_key'] = Array.wrap(params['tag_key'])
      params['tag_key'] << "#{Rails.configuration.cmr_tag_namespace}.extra.subset_service*"
    end

    if features['Map Imagery']
      params['tag_key'] = Array.wrap(params['tag_key'])
      params['tag_key'] << "#{Rails.configuration.cmr_tag_namespace}.extra.gibs"
    end

    # Removed for MAAP
    # if features['Near Real Time']
    #   params = params.merge('collection_data_type' => 'NEAR_REAL_TIME')
    # end

    params['include_tags'] = ["#{Rails.configuration.cmr_tag_namespace}.*",
                              'org.ceos.wgiss.cwic.granules.prod'].join(',')

    # params['include_facets'] = 'v2'

    relevancy_param(params)

    if params['all_collections'].nil? || params['all_collections'].present? && params.delete('all_collections').to_s != 'true'
      params['has_granules_or_cwic'] = true
    end

    params['two_d_coordinate_system'].delete 'coordinates' if params['two_d_coordinate_system'].present?

    params['options[temporal][limit_to_granules]'] = true

    params
  end

  # When a collection search has one of these fields:
  #   keyword
  #   platform
  #   instrument
  #   sensor
  #   two_d_coordinate_system_name
  #   science_keywords
  #   project
  #   processing_level_id
  #   data_center
  #   archive_center
  # We should sort collection results by: sort_key[]=has_granules_or_cwic&sort_key[]=score
  # Otherwise, we should sort collection results by: sort_key[]=has_granules_or_cwic
  def relevancy_param(params)
    # Default the sort key to an empty array in case nothing has been requested yet
    params[:sort_key] ||= []

    # Regardless of the sort_key provided by the user, we always want to sort by `has_granules_or_cwic` first
    params[:sort_key].unshift('has_granules_or_cwic')

    # sensor, archive_center and two_d_coordinate_system_name were removed from the available facets but it doesn't
    # hurt to list them here though.
    relevancy_capable_fields = %w(keyword free_text platform instrument sensor two_d_coordinate_system_name
                                  science_keywords project processing_level_id data_center archive_center)

    # If any of the params provided are relevancy params sort the results by the relevancy score
    params[:sort_key].push('score') unless (params.keys & relevancy_capable_fields).empty?
  end

  # These are facets that do no come back from CMR
  def add_fake_json_facets(facets)
    feature_facet = [
      {
        'title' => 'Features',
        'type' => 'group',
        'applied' => false,
        'has_children' => true,
        'children' => [
          { 'title' => 'Map Imagery', 'type' => 'filter', 'applied' => false, 'has_children' => false }
          # Removed for MAAP
          # { 'title' => 'Near Real Time', 'type' => 'filter', 'applied' => false, 'has_children' => false },
          # { 'title' => 'Customizable', 'type' => 'filter', 'applied' => false, 'has_children' => false }
        ]
      }
    ]

    if facets.present? && facets['children']
      feature_facet + facets['children']
    else
      feature_facet
    end
  end
end
