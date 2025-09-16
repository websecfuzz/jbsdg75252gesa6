# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Search::Elastic::Pagination, feature_category: :global_search do
  include_context 'with filters shared context'

  let(:paginator) { described_class.new(query_hash) }

  before do
    query_hash[:sort] = { created_at: { order: :asc } }
  end

  describe 'without before and after' do
    describe '#first' do
      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates the query without keyset pagination filters' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: []
            }
          },
          sort: [
            { created_at: { order: :asc } },
            { id: { order: :asc } }
          ],
          size: 10
        })
      end
    end

    describe '#last' do
      subject(:last_10_records_query) { paginator.last(10) }

      it 'generates the query without keyset pagination filters' do
        expect(last_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: []
            }
          },
          sort: [
            { created_at: { order: :desc } },
            { id: { order: :desc } }
          ],
          size: 10
        })
      end
    end
  end

  describe '#before' do
    before do
      paginator.before('2025-01-01', 1)
    end

    describe '#first' do
      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates the query' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { lt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { lt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: { order: :asc } },
            { id: { order: :asc } }
          ],
          size: 10
        })
      end
    end

    describe '#last' do
      subject(:last_10_records_query) { paginator.last(10) }

      it 'generates the query' do
        expect(last_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { lt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { lt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: { order: :desc } },
            { id: { order: :desc } }
          ],
          size: 10
        })
      end
    end
  end

  describe '#after' do
    before do
      paginator.after('2025-01-01', 1)
    end

    describe '#first' do
      subject(:first_10_records_query) { paginator.first(10) }

      it 'generates the query' do
        expect(first_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { gt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { gt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: { order: :asc } },
            { id: { order: :asc } }
          ],
          size: 10
        })
      end
    end

    describe '#last' do
      subject(:last_10_records_query) { paginator.last(10) }

      it 'generates the query' do
        expect(last_10_records_query).to eq({
          query: {
            bool: {
              should: [],
              must_not: [],
              must: [],
              filter: [
                {
                  bool: {
                    should: [
                      {
                        range: {
                          created_at: { gt: '2025-01-01' }
                        }
                      },
                      {
                        bool: {
                          must: [
                            {
                              term: {
                                created_at: '2025-01-01'
                              }
                            },
                            {
                              range: {
                                id: { gt: 1 }
                              }
                            }
                          ]
                        }
                      }
                    ]
                  }
                }
              ]
            }
          },
          sort: [
            { created_at: { order: :desc } },
            { id: { order: :desc } }
          ],
          size: 10
        })
      end
    end
  end

  describe 'providing a different tie-breaker property' do
    let(:paginator) { described_class.new(query_hash, :vulnerability_id) }

    subject(:first_10_records_query) { paginator.after('2025-01-01', 1).first(10) }

    it 'generates the query based on given tie-breaker property' do
      expect(first_10_records_query).to eq({
        query: {
          bool: {
            should: [],
            must_not: [],
            must: [],
            filter: [
              {
                bool: {
                  should: [
                    {
                      range: {
                        created_at: { gt: '2025-01-01' }
                      }
                    },
                    {
                      bool: {
                        must: [
                          {
                            term: {
                              created_at: '2025-01-01'
                            }
                          },
                          {
                            range: {
                              vulnerability_id: { gt: 1 }
                            }
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        sort: [
          { created_at: { order: :asc } },
          { vulnerability_id: { order: :asc } }
        ],
        size: 10
      })
    end
  end

  context 'when sort contains more than one sort properties' do
    before do
      query_hash[:sort] = { severity: { order: :asc }, vulnerability_id: { order: :desc } }
    end

    let(:paginator) { described_class.new(query_hash) }

    subject(:first_10_records_query) { paginator.after(2, 100).first(10) }

    it 'generates the query based on second sort property as the tie-breaker property' do
      expect(first_10_records_query).to eq({
        query: {
          bool: {
            should: [],
            must_not: [],
            must: [],
            filter: [
              {
                bool: {
                  should: [
                    {
                      range: {
                        severity: { gt: 2 }
                      }
                    },
                    {
                      bool: {
                        must: [
                          {
                            term: {
                              severity: 2
                            }
                          },
                          {
                            range: {
                              vulnerability_id: { lt: 100 }
                            }
                          }
                        ]
                      }
                    }
                  ]
                }
              }
            ]
          }
        },
        sort: [
          { severity: { order: :asc } },
          { vulnerability_id: { order: :desc } }
        ],
        size: 10
      })
    end
  end
end
