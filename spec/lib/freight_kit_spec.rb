# frozen_string_literal: true

require 'spec_helper'

describe FreightKit do
  it { expect { Zeitwerk::Loader.eager_load_all }.not_to(raise_error) }
end
