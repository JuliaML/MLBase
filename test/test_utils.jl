
function test_zygote(f, xs...; kws...)
    config = ZygoteRuleConfig()
    test_rrule(config, f, xs...; kws..., rrule_f = rrule_via_ad)
end
