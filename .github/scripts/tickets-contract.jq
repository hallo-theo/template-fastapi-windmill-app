# The plan/tickets.json contract (single shared copy — admin-decompose.yml
# validates with it, test-tickets-contract.sh keeps it honest).
# Full contract: hallo-theo/.github -> sdlc/templates/roadmap.md.
type=="array" and length<=12
and (map(.id) | length == (unique | length))
# same-wave tickets run as PARALLEL workers: their areas must be disjoint
# (the same area in DIFFERENT waves is fine — that is sequential work)
and (group_by(.wave) | all(.[]; (map(.area) | length) == (map(.area) | unique | length)))
and ( . as $all | all(.[];
      (.id|type=="string" and test("^TK-[0-9]+$"))
  and (.title|type=="string" and length>0)
  and (.description|type=="string" and length>0)
  and (.acceptance_criteria|type=="array" and length>0 and all(.[]; type=="string" and length>0))
  and (.blocked_by|type=="array" and all(.[]; type=="string"))
  and (.area|type=="string" and length>0)
  and (.wave|type=="number" and .>=1)
  and (.wave as $w | all(.blocked_by[]; . as $dep | any($all[]; .id==$dep and .wave<$w)))
))
