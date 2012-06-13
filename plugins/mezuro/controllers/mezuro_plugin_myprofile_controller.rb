class MezuroPluginMyprofileController < ProfileController

  append_view_path File.join(File.dirname(__FILE__) + '/../views')

 
  def choose_base_tool
    @configuration_name = params[:configuration_name]
    @tool_names = Kalibro::Client::BaseToolClient.new
  end

  def choose_metric
    @configuration_name = params[:configuration_name]
    @collector_name = params[:collector_name]
    @collector = Kalibro::Client::BaseToolClient.new.base_tool(@collector_name)
  end
  
  def new_metric_configuration
    metric_name = params[:metric_name]
    collector_name = params[:collector_name]
    collector = Kalibro::Client::BaseToolClient.new.base_tool(collector_name)
    @metric = collector.supported_metrics.find {|metric| metric.name == metric_name}
    @configuration_name = params[:configuration_name]
  end
  
  def new_compound_metric_configuration
    @configuration_name = params[:configuration_name]
    @metric_configurations = Kalibro::Client::ConfigurationClient.new.configuration(@configuration_name).metric_configurations
  end
  
  def edit_metric_configuration
    metric_name = params[:metric_name]
    @configuration_name = params[:configuration_name]
    @metric_configuration = Kalibro::Client::MetricConfigurationClient.new.metric_configuration(@configuration_name, metric_name)
    @metric = @metric_configuration.metric
  end

  def edit_compound_metric_configuration
    metric_name = params[:metric_name]
    @configuration_name = params[:configuration_name]
    @metric_configuration = Kalibro::Client::MetricConfigurationClient.new.metric_configuration(@configuration_name, metric_name)
    @metric_configurations = Kalibro::Client::ConfigurationClient.new.configuration(@configuration_name).metric_configurations
    @metric = @metric_configuration.metric
  end
  
  def create_metric_configuration
    generic_metric_configuration_creation(new_metric_configuration_instance)
    redirect_to "/#{profile.identifier}/#{@configuration_name.downcase.gsub(/\s/, '-')}"
  end
  
  def create_compound_metric_configuration
    generic_metric_configuration_creation(new_compound_metric_configuration_instance)
    redirect_to "/#{profile.identifier}/#{@configuration_name.downcase.gsub(/\s/, '-')}"    
  end

  def update_metric_configuration
    auxiliar_update_metric_configuration(MezuroPlugin::MetricConfigurationContent::NATIVE_TYPE)
    redirect_to "/#{profile.identifier}/#{@configuration_name.downcase.gsub(/\s/, '-')}"
  end

  def update_compound_metric_configuration
    auxiliar_update_metric_configuration(MezuroPlugin::MetricConfigurationContent::COMPOUND_TYPE)
    redirect_to "/#{profile.identifier}/#{@configuration_name.downcase.gsub(/\s/, '-')}"
  end
  
  def new_range
    @metric_name = params[:metric_name]
    @configuration_name = params[:configuration_name]
  end
  
  def edit_range
    @metric_name = params[:metric_name]
    @configuration_name = params[:configuration_name]
    @beginning_id = params[:beginning_id]
    
    metric_configuration_client = Kalibro::Client::MetricConfigurationClient.new
    metric_configuration = metric_configuration_client.metric_configuration(@configuration_name, @metric_name)
    @range = metric_configuration.ranges.find{ |range| range.beginning == @beginning_id.to_f }
  end

  def create_range
    @range = new_range_instance
    configuration_name = params[:configuration_name]
    metric_name = params[:metric_name]
    beginning_id = params[:beginning_id]
    metric_configuration_client = Kalibro::Client::MetricConfigurationClient.new
    metric_configuration = metric_configuration_client.metric_configuration(configuration_name, metric_name)   
    metric_configuration.add_range(@range)
    metric_configuration_client.save(metric_configuration, configuration_name)
  end
  
  def update_range
    metric_name = params[:metric_name]
    configuration_name = params[:configuration_name]
    beginning_id = params[:beginning_id]
    metric_configuration_client = Kalibro::Client::MetricConfigurationClient.new
    metric_configuration = metric_configuration_client.metric_configuration(configuration_name, metric_name)
    index = metric_configuration.ranges.index{ |range| range.beginning == beginning_id.to_f }
    metric_configuration.ranges[index] = new_range_instance
    Kalibro::Client::MetricConfigurationClient.new.save(metric_configuration, configuration_name)
  end
  
  def remove_range
    configuration_name = params[:configuration_name]
    metric_name = params[:metric_name]
    beginning_id = params[:range_beginning]
    metric_configuration_client = Kalibro::Client::MetricConfigurationClient.new
    metric_configuration = metric_configuration_client.metric_configuration(configuration_name, metric_name)
    metric_configuration.ranges.delete_if { |range| range.beginning == beginning_id.to_f }.inspect
    Kalibro::Client::MetricConfigurationClient.new.save(metric_configuration, configuration_name)
    formatted_configuration_name = configuration_name.gsub(/\s/, '+')
    formatted_metric_name = metric_name.gsub(/\s/, '+')
    if metric_configuration.metric.class == Kalibro::Entities::CompoundMetric
      redirect_to "/myprofile/#{profile.identifier}/plugin/mezuro/edit_compound_metric_configuration?configuration_name=#{formatted_configuration_name}&metric_name=#{formatted_metric_name}"
    else
      redirect_to "/myprofile/#{profile.identifier}/plugin/mezuro/edit_metric_configuration?configuration_name=#{formatted_configuration_name}&metric_name=#{formatted_metric_name}"
    end
  end

  def remove_metric_configuration
    configuration_name = params[:configuration_name]
    metric_name = params[:metric_name]
    Kalibro::Client::MetricConfigurationClient.new.remove(configuration_name, metric_name)
    redirect_to "/#{profile.identifier}/#{configuration_name.downcase.gsub(/\s/, '-')}"
  end

  private 

  def new_metric_configuration_instance
    metric_configuration = Kalibro::Entities::MetricConfiguration.new
    metric_configuration.metric = Kalibro::Entities::NativeMetric.new
    assign_metric_configuration_instance(metric_configuration, MezuroPlugin::MetricConfigurationContent::NATIVE_TYPE)
  end
  
  def new_compound_metric_configuration_instance
    metric_configuration = Kalibro::Entities::MetricConfiguration.new
    metric_configuration.metric = Kalibro::Entities::CompoundMetric.new
    assign_metric_configuration_instance(metric_configuration, MezuroPlugin::MetricConfigurationContent::COMPOUND_TYPE)
  end
  
  def assign_metric_configuration_instance(metric_configuration, type=MezuroPlugin::MetricConfigurationContent::NATIVE_TYPE)
    metric_configuration.metric.name = params[:metric_configuration][:metric][:name]
    metric_configuration.metric.description = params[:metric_configuration][:metric][:description]
    metric_configuration.metric.scope = params[:metric_configuration][:metric][:scope]
    metric_configuration.code = params[:metric_configuration][:code]
    metric_configuration.weight = params[:metric_configuration][:weight]
    metric_configuration.aggregation_form = params[:metric_configuration][:aggregation_form]
    
    if type == MezuroPlugin::MetricConfigurationContent::NATIVE_TYPE
      metric_configuration.metric.origin = params[:metric_configuration][:metric][:origin]
      metric_configuration.metric.language = params[:metric_configuration][:metric][:language]
    elsif type == MezuroPlugin::MetricConfigurationContent::COMPOUND_TYPE
      metric_configuration.metric.script = params[:metric_configuration][:metric][:script]
    end
  end
  
  def generic_metric_configuration_creation(metric_configuration)
    @configuration_name = params[:configuration_name]
    Kalibro::Client::MetricConfigurationClient.new.save(metric_configuration, @configuration_name)
  end
  
  def auxiliar_update_metric_configuration(type)
    @configuration_name = params[:configuration_name]
    metric_name = params[:metric_configuration][:metric][:name]
    metric_configuration_client = Kalibro::Client::MetricConfigurationClient.new
    metric_configuration = metric_configuration_client.metric_configuration(@configuration_name, metric_name)  
    metric_configuration = assign_metric_configuration_instance(metric_configuration, type)
    metric_configuration_client.save(metric_configuration, @configuration_name)
  end

  def new_range_instance
    range = Kalibro::Entities::Range.new
    range.beginning = params[:range][:beginning]
    range.end = params[:range][:end]
    range.label = params[:range][:label]
    range.grade = params[:range][:grade]
    range.color = params[:range][:color]
    range.comments = params[:range][:comments]
    range
  end

end
