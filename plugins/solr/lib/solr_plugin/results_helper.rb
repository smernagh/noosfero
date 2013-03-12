class SolrPlugin < Noosfero::Plugin
  module ResultsHelper
    def asset_class(asset)
      asset.to_s.singularize.camelize.constantize
    end

    def set_facets_variables
      @facets = @searches[@asset][:facets]
      @all_facets = @searches[@asset][:all_facets]
    end

    def order_by(asset)
      options = SolrPlugin::SortOptions[asset].map do |name, options|
        next if options[:if] && !instance_eval(&options[:if])
        [_(options[:label]), name.to_s]
      end.compact

      content_tag('div', _('Sort results by ') +
        select_tag(asset.to_s + '[order]', options_for_select(options, params[:order_by] || 'none'),
          {:onchange => "window.location = jQuery.param.querystring(window.location.href, { 'order_by' : this.options[this.selectedIndex].value})"}
        ),
        :class => "search-ordering"
      )
    end

    def label_total_found(asset, total_found)
      labels = {
        :products => _("%s products offers found"),
        :articles => _("%s articles found"),
        :events => _("%s events found"),
        :people => _("%s people found"),
        :enterprises => _("%s enterprises found"),
        :communities => _("%s communities found"),
      }
      content_tag('span', labels[asset] % total_found,
        :class => "total-pages-found") if labels[asset]
    end

    def facets_menu(asset, _facets)
      @asset_class = asset_class(asset)
      @facets = _facets
      render(:partial => 'facets_menu')
    end

    def facets_unselect_menu(asset)
      @asset_class = asset_class(asset)
      render(:partial => 'facets_unselect_menu')
    end

    def facet_selecteds_html_for(environment, klass, params)
      def name_with_extra(klass, facet, value)
        name = klass.facet_result_name(facet, value)
        name = name[0] + name[1] if name.kind_of?(Array)
        name
      end

      ret = []
      params = params.dup
      params[:facet].each do |id, value|
        facet = klass.facet_by_id(id.to_sym)
        next unless facet
        if value.kind_of?(Hash)
          label_hash = facet[:label].call(environment)
          value.each do |label_id, value|
            facet[:label_id] = label_id
            facet[:label] = label_hash[label_id]
            value.to_a.each do |value|
              ret << [facet[:label], name_with_extra(klass, facet, value),
                params.merge(:facet => params[:facet].merge(id => params[:facet][id].merge(label_id => params[:facet][id][label_id].to_a.reject{ |v| v == value })))]
            end
          end
        else
          ret << [klass.facet_label(facet), name_with_extra(klass, facet, value),
            params.merge(:facet => params[:facet].reject{ |k,v| k == id })]
        end
      end

      ret.map do |label, name, url|
        content_tag('div', content_tag('span', label, :class => 'facet-selected-label') +
          content_tag('span', name, :class => 'facet-selected-name') +
          link_to('', url, :class => 'facet-selected-remove', :title => 'remove facet'), :class => 'facet-selected')
      end.join
    end

    def facet_link_html(facet, params, value, label, count)
      params = params ? params.dup : {}
      has_extra = label.kind_of?(Array)
      link_label = has_extra ? label[0] : label
      id = facet[:solr_field].to_s
      params[:facet] ||= {}
      params[:facet][id] ||= {}
      params[:page] = {} if params[:page]

      selected = facet[:label_id].nil? ? params[:facet][id] == value : params[:facet][id][facet[:label_id]].to_a.include?(value)

      if count > 0
        url = params.merge(:facet => params[:facet].merge(
          id => facet[:label_id].nil? ? value : params[:facet][id].merge( facet[:label_id] => params[:facet][id][facet[:label_id]].to_a | [value] )
        ))
      else
        # preserve others filters and change this filter
        url = params.merge(:facet => params[:facet].merge(
          id => facet[:label_id].nil? ? value : { facet[:label_id] => value }
        ))
      end

      content_tag 'div', link_to(link_label, url, :class => 'facet-result-link-label') +
          content_tag('span', (has_extra ? label[1] : ''), :class => 'facet-result-extra-label') +
          (count > 0 ? content_tag('span', " (#{count})", :class => 'facet-result-count') : ''),
        :class => 'facet-menu-item' + (selected ? ' facet-result-link-selected' : '')
    end

    def facet_javascript(input_id, facet, array)
      array = [] if array.nil?
      hintText = _('Type in an option')
      text_field_tag('facet['+input_id+']', '', :id => input_id) +
        javascript_tag("jQuery.TokenList(jQuery('##{input_id}'), #{array.to_json},
          {searchDelay: 0, permanentDropdown: true, theme: 'facet', dontAdd: true, preventDuplicates: true,
          #{jquery_token_input_messages_json(hintText)}});")
    end
  end
end
