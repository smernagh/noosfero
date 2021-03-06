module Api
  module V1
    class Search < Grape::API

      resource :search do
        resource :article do
          paginate max_per_page: 200
          get do
            # Security checks
            sanitize_params_hash(params)
            # Api::Helpers
            asset = :articles
            context = environment

            profile = environment.profiles.find(params[:profile_id]) if params[:profile_id]
            scope = profile.nil? ? environment.articles.is_public : profile.articles.is_public
            scope = scope.where(:type => params[:type]) if params[:type] && !(params[:type] == 'Article')
            scope = scope.where(make_conditions_with_parameter(params))
            scope = scope.joins(:categories).where(:categories => {:id => params[:category_ids]}) if params[:category_ids].present?
            scope = scope.where('articles.children_count > 0') if params[:has_children].present?
            query = params[:query] || ""
            order = "more_recent"

            options = {filter: order, template_id: params[:template_id], tag: params[:tag]}

            search_result = find_by_contents(asset, context, scope, query, {:page => 1}, options)

            articles = search_result[:results]
            status Api::Status::DEPRECATED
            present_articles(articles)
          end
        end
      end

    end
  end
end
