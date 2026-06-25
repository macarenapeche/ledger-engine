module Ledger
  class Error < StandardError; end
  class UnbalancedEntry < Error; end
  class InsufficientFunds < Error; end
  class AccountNotFound < Error; end
  class CurrencyMismatch < Error; end
end
