# Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
# SPDX-License-Identifier: Apache-2.0

import ..Singleton

"""
    is_including(singleton::Singleton, dom::Domain)

Check if dom ⊂ singleton
"""
is_including(singleton::Singleton{Int}, dom::Domain) = isbound(dom) && minimum(dom) == singleton.value

is_overlapping(singleton::Singleton{Int}, dom::Domain) = singleton.value in dom

is_intersecting(singleton::Singleton{Int}, dom::Domain) = singleton.value in dom

Base.in(value::Int, singleton::Singleton{Int}) = singleton.value == value

remove!(dom::Domain, singleton::Singleton{Int}) = remove!(dom, singleton.value)

remove_all_but!(dom::Domain, singleton::Singleton{Int}) = remove_all_but!(dom, singleton.value)

function Base.show(io::IO, singleton::Singleton{Int})
    print(io, "{$(singleton.value)}")
end

function Base.show(io::IO, ::MIME"text/plain", singleton::Singleton{Int})
    print(io, "{$(singleton.value)}")
end