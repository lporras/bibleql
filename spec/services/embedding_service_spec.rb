require "rails_helper"

RSpec.describe EmbeddingService do
  let(:fake_vector) { Array.new(256) { rand(-1.0..1.0) } }

  describe ".embed" do
    it "returns a vector for a single text" do
      embedding = instance_double(RubyLLM::Embedding, vectors: fake_vector)
      allow(RubyLLM).to receive(:embed).and_return(embedding)

      result = described_class.embed("fe y esperanza")

      expect(result).to eq(fake_vector)
      expect(result.length).to eq(256)
      expect(RubyLLM).to have_received(:embed).with("fe y esperanza", model: "text-embedding-3-small", dimensions: 256)
    end
  end

  describe ".embed_batch" do
    it "returns vectors for multiple texts" do
      vectors = [ fake_vector, fake_vector.reverse ]
      embedding = instance_double(RubyLLM::Embedding, vectors: vectors)
      allow(RubyLLM).to receive(:embed).and_return(embedding)

      result = described_class.embed_batch([ "text one", "text two" ])

      expect(result.length).to eq(2)
      expect(result.first.length).to eq(256)
      expect(RubyLLM).to have_received(:embed).with([ "text one", "text two" ], model: "text-embedding-3-small", dimensions: 256)
    end
  end
end
