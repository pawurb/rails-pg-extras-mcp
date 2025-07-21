# frozen_string_literal: true

require "spec_helper"
require "rails-pg-extras-mcp"

describe RailsPgExtrasMcp do
  it "works" do
    expect {
      RailsPgExtrasMcp::App.build
    }.not_to raise_error
  end
end
