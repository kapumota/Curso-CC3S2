package local.plan

deny[msg] {
  some k
  v := input.outputs[k]
  re_match("(?i)(key|secret|token|password)", to_string(v))
  msg := sprintf("Output '%s' revela posible secreto", [k])
}
