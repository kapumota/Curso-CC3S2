package local.plan

deny[msg] {
  some i
  create := input.creates[i]
  create.public == true
  msg := sprintf("Bucket %s no puede ser público", [create.name])
}

deny[msg] {
  some j
  update := input.updates[j]
  update.changes.public.to == true
  msg := sprintf("Update pone público el bucket %s", [update.name])
}
