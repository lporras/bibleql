class EmbeddingService
  MODEL = "text-embedding-3-small"
  DIMENSIONS = 256

  def self.embed(text)
    RubyLLM.embed(text, model: MODEL, dimensions: DIMENSIONS).vectors
  end

  def self.embed_batch(texts)
    RubyLLM.embed(texts, model: MODEL, dimensions: DIMENSIONS).vectors
  end
end
