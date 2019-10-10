local util = import '_util.libsonnet';

{
  errorbudget(param):: {
    local slo = {
      metric: error 'must set metric for errorburn',
      selectors: error 'must set selectors for errorburn',
      errorBudget: error 'must set errorBudget for errorburn',
      labels: [],
      codeSelector: 'code',
    } + param,

    local labels =
      util.selectorsToLabels(slo.selectors) +
      util.selectorsToLabels(slo.labels),

    local requestsTotal = {
      record: 'status_code:%s:increase30d:sum' % slo.metric,
      expr: |||
        sum(label_replace(increase(%s{%s}[30d]), "status_code", "${1}xx", "%s", "([0-9])..")) by (status_code)
      ||| % [
        slo.metric,
        std.join(',', slo.selectors),
        slo.codeSelector,
      ],
      labels: labels,
    },

    local errorsTotal = {
      record: 'errors:%s' % requestsTotal.record,
      expr: |||
        %s{%s}
      ||| % [
        requestsTotal.record,
        std.join(',', slo.selectors + ['status_code="5xx"']),
      ],
      labels: labels,
    },

    local errorBudgetRequests = {
      record: 'errorbudget_requests:%s' % requestsTotal.record,
      expr: |||
        (%f) * sum(%s)
      ||| % [
        slo.errorBudget,
        requestsTotal.record,
      ],
      labels: labels,
    },

    local errorBudgetRemaining = {
      record: 'errorbudget_remaining:%s' % requestsTotal.record,
      expr: |||
        sum(%s{%s}) - sum(%s{%s})
      ||| % [
        errorBudgetRequests.record,
        std.join(',', slo.selectors),
        errorsTotal.record,
        std.join(',', slo.selectors),
      ],
      labels: labels,
    },

    local errorBudget = {
      record: 'errorbudget:%s' % requestsTotal.record,
      expr: |||
        %s / %s
      ||| % [
        errorBudgetRemaining.record,
        errorBudgetRequests.record,
      ],
      labels: labels,
    },

    recordingrules: [
      requestsTotal,
      errorsTotal,
      errorBudgetRequests,
      errorBudgetRemaining,
      errorBudget,
    ],
  },
}
