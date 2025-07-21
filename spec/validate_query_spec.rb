# frozen_string_literal: true

require "spec_helper"
require "rails-pg-extras-mcp"

RSpec.describe ValidateQuery do
  subject { described_class.new(query) }

  describe "#call" do
    context "with a valid SELECT query" do
      let(:query) { "SELECT * FROM users" }

      it "returns true" do
        expect(subject.call).to eq(true)
      end
    end

    context "with nested SELECT statements" do
      let(:query) { "SELECT * FROM users WHERE id IN (SELECT user_id FROM posts WHERE published = true)" }

      it "returns true" do
        expect(subject.call).to eq(true)
      end
    end

    context "with multiple statements" do
      let(:query) { "SELECT * FROM users; SELECT * FROM posts" }

      it "raises an error" do
        expect { subject.call }.to raise_error(ValidateQuery::InvalidQueryError, /Multiple SQL statements/)
      end
    end

    context "with a denied keyword" do
      let(:query) { "DROP TABLE users" }

      it "raises an error" do
        expect { subject.call }.to raise_error(ValidateQuery::InvalidQueryError, /denied keyword/)
      end
    end

    context "with a non-SELECT query" do
      let(:query) { "EXPLAIN SELECT * FROM users" }

      it "raises an error" do
        expect { subject.call }.to raise_error(ValidateQuery::InvalidQueryError)
      end
    end

    context "with invalid SQL syntax" do
      let(:query) { "SELECT FROM WHERE" }

      it "raises an error" do
        expect { subject.call }.to raise_error(ValidateQuery::InvalidQueryError, /Invalid SQL syntax/)
      end
    end

    context "with an empty query" do
      let(:query) { "   " }

      it "raises an error" do
        expect { subject.call }.to raise_error(ValidateQuery::InvalidQueryError, /Query is empty/)
      end
    end
  end
end
