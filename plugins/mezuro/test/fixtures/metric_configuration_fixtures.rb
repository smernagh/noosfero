class MetricConfigurationFixtures

  def self.amloc_configuration
    amloc = Kalibro::Entities::MetricConfiguration.new
    amloc.metric = NativeMetricFixtures.amloc
    amloc.code = 'amloc'
    amloc.weight = 1.0
    amloc.aggregation_form = 'AVERAGE'
    amloc.ranges = [RangeFixtures.amloc_excellent, RangeFixtures.amloc_bad]
    amloc
  end

  def self.sc_configuration
    sc = Kalibro::Entities::MetricConfiguration.new
    sc.metric = CompoundMetricFixtures.sc
    sc.code = 'sc'
    sc.weight = 1.0
    sc.aggregation_form = 'AVERAGE'
    sc
  end

  def self.amloc_configuration_hash
    {:metric => NativeMetricFixtures.amloc_hash, :code => 'amloc', :weight => 1.0,
      :aggregation_form => 'AVERAGE', :range =>
        [RangeFixtures.amloc_excellent_hash, RangeFixtures.amloc_bad_hash]}
  end

  def self.sc_configuration_hash
    {:metric => CompoundMetricFixtures.sc_hash, :code => 'sc', :weight => 1.0, :aggregation_form => 'AVERAGE'}
  end
    
end
