# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import ..Interval

"""
    is_including(interval::Interval, dom::Domain)

Check if dom ⊂ interval
"""
is_including(interval::Interval{Int}, dom::Domain) = interval.inf <= minimum(dom) && interval.sup >= maximum(dom)

"""
    is_overlapping(interval::Interval{Int}, dom::Domain)

Check if min(dom) ≤ interval.sup && max(dom) ≥ interval.inf. If not, this means that their intersection is empty.
"""
is_overlapping(interval::Interval{Int}, dom::Domain) = minimum(dom) <= interval.sup && maximum(dom) >= interval.inf

"""
    is_intersecting(interval::Interval{Int}, dom::Domain)

Check if dom ∩ interval ≠ ∅
"""
function is_intersecting(interval::Interval{Int}, dom::Domain)
    for v in dom
        if v in interval
            return true
        end
    end
    return false
end

Base.in(value::Int, interval::Interval{Int}) = value <= interval.sup && value >= interval.inf

"""
    remove!(dom::Domain, interval::Interval{Int}) 

Remove the value between interval.inf and interval.sup in domain (including the bounds)
"""
remove!(dom::Domain, interval::Interval{Int}) = remove_between!(dom, interval.inf - 1, interval.sup + 1)

function remove_all_but!(dom::Domain, interval::Interval{Int})
    pruned_min = remove_below!(dom, interval.inf)
    pruned_max = remove_above!(dom, interval.sup)
    return pruned_min || pruned_max
end

function Base.show(io::IO, interval::Interval{Int})
    print(io, "[", interval.inf, ", ", interval.sup, "]")
end

function Base.show(io::IO, ::MIME"text/plain", interval::Interval{Int})
    print(io, "[", interval.inf, ", ", interval.sup, "]")
end
