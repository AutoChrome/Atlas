module SearchStubTestHelper
  # Swaps a Searchkick model's .search for the duration of the block, then
  # restores the original — avoids depending on a real search index being
  # populated (fixtures bypass the callbacks that would normally reindex a
  # record) or pulling in a mocking gem for one class-method stub.
  def with_search_stub(model, replacement)
    original = model.method(:search)
    model.define_singleton_method(:search, replacement)
    yield
  ensure
    model.define_singleton_method(:search, original)
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) do
  include SearchStubTestHelper
end
