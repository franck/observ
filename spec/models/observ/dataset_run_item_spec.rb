# frozen_string_literal: true

require "rails_helper"

RSpec.describe Observ::DatasetRunItem, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      run_item = build(:observ_dataset_run_item)
      expect(run_item).to be_valid
    end

    it "requires unique dataset_item per dataset_run" do
      run = create(:observ_dataset_run)
      item = create(:observ_dataset_item, dataset: run.dataset)
      create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      duplicate = build(:observ_dataset_run_item, dataset_run: run, dataset_item: item)
      expect(duplicate).not_to be_valid
    end

    it "allows same item in different runs" do
      dataset = create(:observ_dataset)
      item = create(:observ_dataset_item, dataset: dataset)
      run1 = create(:observ_dataset_run, dataset: dataset)
      run2 = create(:observ_dataset_run, dataset: dataset)

      create(:observ_dataset_run_item, dataset_run: run1, dataset_item: item)
      run_item2 = build(:observ_dataset_run_item, dataset_run: run2, dataset_item: item)

      expect(run_item2).to be_valid
    end
  end

  describe "associations" do
    it "belongs to a dataset_run" do
      run = create(:observ_dataset_run)
      item = create(:observ_dataset_item, dataset: run.dataset)
      run_item = create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      expect(run_item.dataset_run).to eq(run)
    end

    it "belongs to a dataset_item" do
      run = create(:observ_dataset_run)
      item = create(:observ_dataset_item, dataset: run.dataset)
      run_item = create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      expect(run_item.dataset_item).to eq(item)
    end

    it "optionally belongs to a trace" do
      session = create(:observ_session)
      trace = create(:observ_trace, observ_session: session)
      run_item = create(:observ_dataset_run_item, :succeeded, trace: trace)

      expect(run_item.trace).to eq(trace)
    end

    it "optionally belongs to an observation" do
      run_item = build(:observ_dataset_run_item)
      expect(run_item.observation).to be_nil
      expect(run_item).to be_valid
    end
  end

  describe "status helpers" do
    describe "#succeeded?" do
      it "returns true when trace exists and no error" do
        session = create(:observ_session)
        trace = create(:observ_trace, observ_session: session)
        run_item = create(:observ_dataset_run_item, trace: trace, error: nil)

        expect(run_item.succeeded?).to be true
      end

      it "returns false when error exists" do
        session = create(:observ_session)
        trace = create(:observ_trace, observ_session: session)
        run_item = build(:observ_dataset_run_item, trace: trace, error: "Some error")

        expect(run_item.succeeded?).to be false
      end

      it "returns false when no trace" do
        run_item = build(:observ_dataset_run_item, trace: nil)
        expect(run_item.succeeded?).to be false
      end
    end

    describe "#failed?" do
      it "returns true when error exists" do
        run_item = build(:observ_dataset_run_item, :failed)
        expect(run_item.failed?).to be true
      end

      it "returns false when no error" do
        run_item = build(:observ_dataset_run_item, error: nil)
        expect(run_item.failed?).to be false
      end
    end

    describe "#pending?" do
      it "returns true when no trace and no error" do
        run_item = build(:observ_dataset_run_item, trace: nil, error: nil)
        expect(run_item.pending?).to be true
      end

      it "returns false when trace exists" do
        session = create(:observ_session)
        trace = create(:observ_trace, observ_session: session)
        run_item = build(:observ_dataset_run_item, trace: trace)

        expect(run_item.pending?).to be false
      end

      it "returns false when error exists" do
        run_item = build(:observ_dataset_run_item, :failed)
        expect(run_item.pending?).to be false
      end
    end

    describe "#status" do
      it "returns :failed when error exists" do
        run_item = build(:observ_dataset_run_item, :failed)
        expect(run_item.status).to eq(:failed)
      end

      it "returns :succeeded when trace exists without error" do
        session = create(:observ_session)
        trace = create(:observ_trace, observ_session: session)
        run_item = build(:observ_dataset_run_item, trace: trace, error: nil)

        expect(run_item.status).to eq(:succeeded)
      end

      it "returns :pending when neither trace nor error exists" do
        run_item = build(:observ_dataset_run_item, trace: nil, error: nil)
        expect(run_item.status).to eq(:pending)
      end
    end
  end

  describe "access helpers" do
    let(:dataset) { create(:observ_dataset) }
    let(:dataset_item) do
      create(:observ_dataset_item,
        dataset: dataset,
        input: { question: "What is 2+2?" },
        expected_output: { answer: "4" })
    end
    let(:run) { create(:observ_dataset_run, dataset: dataset) }
    let(:run_item) { create(:observ_dataset_run_item, dataset_run: run, dataset_item: dataset_item) }

    describe "#input" do
      it "returns the dataset_item input" do
        expect(run_item.input).to eq({ "question" => "What is 2+2?" })
      end
    end

    describe "#expected_output" do
      it "returns the dataset_item expected_output" do
        expect(run_item.expected_output).to eq({ "answer" => "4" })
      end
    end

    describe "#actual_output" do
      it "returns nil when no trace" do
        expect(run_item.actual_output).to be_nil
      end

      it "returns trace output when trace exists" do
        session = create(:observ_session)
        trace = create(:observ_trace, observ_session: session, output: "The answer is 4")
        run_item.update!(trace: trace)

        expect(run_item.actual_output).to eq("The answer is 4")
      end
    end
  end

  describe "#output_matches?" do
    it "returns nil when expected_output is blank" do
      item = create(:observ_dataset_item, expected_output: nil)
      run = create(:observ_dataset_run, dataset: item.dataset)
      run_item = create(:observ_dataset_run_item, dataset_run: run, dataset_item: item)

      expect(run_item.output_matches?).to be_nil
    end

    it "returns nil when actual_output is blank" do
      run_item = build(:observ_dataset_run_item, trace: nil)
      expect(run_item.output_matches?).to be_nil
    end

    it "returns true when outputs match" do
      item = create(:observ_dataset_item, expected_output: "Paris")
      run = create(:observ_dataset_run, dataset: item.dataset)
      session = create(:observ_session)
      trace = create(:observ_trace, observ_session: session, output: "Paris")
      run_item = create(:observ_dataset_run_item, dataset_run: run, dataset_item: item, trace: trace)

      expect(run_item.output_matches?).to be true
    end

    it "returns false when outputs differ" do
      item = create(:observ_dataset_item, expected_output: "Paris")
      run = create(:observ_dataset_run, dataset: item.dataset)
      session = create(:observ_session)
      trace = create(:observ_trace, observ_session: session, output: "London")
      run_item = create(:observ_dataset_run_item, dataset_run: run, dataset_item: item, trace: trace)

      expect(run_item.output_matches?).to be false
    end
  end

  describe "metrics from trace" do
    let(:session) { create(:observ_session) }
    let(:trace) do
      create(:observ_trace,
        observ_session: session,
        total_cost: 0.0025,
        total_tokens: 150,
        start_time: Time.current,
        end_time: Time.current + 2.seconds)
    end
    let(:run_item) { create(:observ_dataset_run_item, :succeeded, trace: trace) }

    describe "#cost" do
      it "returns trace total_cost" do
        expect(run_item.cost).to eq(0.0025)
      end

      it "returns nil when no trace" do
        run_item = build(:observ_dataset_run_item, trace: nil)
        expect(run_item.cost).to be_nil
      end
    end

    describe "#tokens" do
      it "returns trace total_tokens" do
        expect(run_item.tokens).to eq(150)
      end
    end

    describe "#duration_ms" do
      it "returns trace duration_ms" do
        expect(run_item.duration_ms).to be_within(1).of(2000.0)
      end
    end
  end

  describe "traits" do
    it "creates succeeded run_item with :succeeded trait" do
      run_item = create(:observ_dataset_run_item, :succeeded)
      expect(run_item.succeeded?).to be true
    end

    it "creates failed run_item with :failed trait" do
      run_item = create(:observ_dataset_run_item, :failed)
      expect(run_item.failed?).to be true
      expect(run_item.error).to be_present
    end
  end
end
