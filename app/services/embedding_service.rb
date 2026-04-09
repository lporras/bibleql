class EmbeddingService
  MODEL = "text-embedding-3-small"

  def self.embed(text)
    RubyLLM.embed(text, model: MODEL).vectors
  end

  def self.embed_batch(texts)
    RubyLLM.embed(texts, model: MODEL).vectors
  end
end
