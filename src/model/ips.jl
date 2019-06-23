struct IPSReactionStruct
  pairwise :: Bool
  input1   :: Int # center
  input2   :: Int # adjacent
  output1  :: Int # center
  output2  :: Int # adjacent
  class    :: Int
  rate     :: Float64
  # formula    :: Expr
  # parameter  :: Symbol
  # paramidx   :: Int

  function IPSReactionStruct(pairwise, i1, i2, o1, o2, class, rate)
    if has_invalid_type(pairwise, i1, i2, o1, o2)
      throw(ErrorException("""
      Particle types must be positive integers. Non-pairwise reactions must have the adjacent types be zero.

      pairwise? $pairwise
      center:   $i1 -> $o1
      adjacent: $i2 -> $o2
      """))
    end

    if has_same_types(pairwise, i1, i2, o1, o2)
      throw(ErrorException("""
      At least one particle type must be different.

      pairwise? $pairwise
      center:   $i1 -> $o1
      adjacent: $i2 -> $o2
      """))
    end

    if has_invalid_class(class)
      throw(ErrorException("Assigned class must be a positive integer; class = $class"))
    end

    if has_invalid_rate(rate)
      throw(ErrorException("Reaction rate must be a non-negative real number; rate = $rate"))
    end

    return new(pairwise, i1, i2, o1, o2, class, rate)
  end
end

function Base.show(io::IO, x::IPSReactionStruct)
  i1, i2 = x.input1, x.input2
  o1, o2 = x.output1, x.output2

  if x.pairwise
    str = "$(i1) + $(i2) --> $(o1) + $(o2)"
  else
    str = "$(i1) --> $(o1)"
  end

  print(io, str, "  class = ", x.class)
end

function Base.show(io::IO, m::MIME"text/plain", x::IPSReactionStruct)
  show(io, x)
end

@inline function has_invalid_type(pairwise, i1, i2, o1, o2)
  if pairwise
    # all types must be positive integers
    is_invalid = (i1 < 1) || (i2 < 1) || (o1 < 1) || (o2 < 1)
  else
    # center types must be positve
    # adjacent type must be zero
    is_invalid = (i1 < 1) || (o1 < 1) || (i2 != 0) || (o2 != 0)
  end

  return is_invalid
end

@inline function has_same_types(pairwise, i1, i2, o1, o2)
  if pairwise
    is_invalid = (i1 == i2) && (i2 == o1) && (o1 == o2)
  else
    is_invalid = (i1 == o1)
  end

  return is_invalid
end

@inline function has_invalid_class(class)
  # class must be a positive integer
  class < 1
end

@inline function has_invalid_rate(rate)
  # rate must be a non-negative real number
  rate < 0
end

ispairwise(x::IPSReactionStruct) = x.pairwise

@inline get_reactant_types(x::IPSReactionStruct) = (x.input1, x.input2)
@inline get_product_types(x::IPSReactionStruct) = (x.output1, x.output2)

##### pretty printing #####

function _print_formula(x::IPSReactionStruct)
  ex = formula(x)
  return string(ex.args[1], " ", "→", " ", ex.args[2])
end

# struct InteractingParticleSystem{DG,enumType}
struct InteractingParticleSystem{enumType}
  reactions::Vector{IPSReactionStruct}
  # rxn_rates::Vector{T}
  # dep_graph::DG
  # spc_graph::DG
  # rxn_graph::DG
  isactive::Vector{Bool}
  enumeration::enumType
end

function InteractingParticleSystem(reactions::Vector{IPSReactionStruct}, isactive, enumeration)
  num_reactions = length(reactions)

  # dep_graph = rxnrxn_depgraph(DGLazy(), reactions, isactive, enumeration)

  # return InteractingParticleSystem(reactions, rxn_rates, dep_graph, spc_graph, rxn_graph)
  # return InteractingParticleSystem(reactions, dep_graph, isactive, enumeration)
  return InteractingParticleSystem(reactions, isactive, enumeration)
end

function Base.summary(io::IO, x::InteractingParticleSystem)
  types = length(x.isactive) - 1
  print(io, "Interacting Particle System w/ $(types) type")
end

function Base.show(io::IO, x::InteractingParticleSystem)
  summary(io, x)
  println()
  show(io, x.reactions)
end

function Base.show(io::IO, m::MIME"text/plain", x::InteractingParticleSystem)
  summary(io, x)
  println()
  show(io, m, x.reactions)
end

#
# ##### execute_jump! #####
#
# execute_jump!(state, model::InteractingParticleSystem, j) = execute_jump!(state, model.reactions[j])
#
# function execute_jump!(lattice::AbstractLattice, reaction::IPSReactionStruct)
#   xclass = lattice.xclass
#   xdiff  = lattice.xdiff
#
#   # save counts in each class
#   for s in eachindex(xclass)
#     xdiff[s] = false
#     xclass[s] = length(lattice.classes[s].members)
#   end
#
#   if ispairwise(reaction)
#     # println("pairwise")
#     execute_pairwise!(lattice, reaction)
#   else
#     # println("onsite")
#     execute_onsite!(lattice, reaction)
#   end
#
#   # check which counts have changed
#   for s in eachindex(xclass)
#     if xclass[s] != length(lattice.classes[s].members)
#       xdiff[s] = true
#     end
#   end
#
#   return nothing
# end
#
# ##### SLattice subroutines #####
#
# function execute_pairwise!(lattice::SLattice, reaction)
#   # unpack reaction information
#   i1, i2 = get_reactant_types(reaction)
#   j1, j2 = get_product_types(reaction)
#
#   s = reaction.class
#
#   # unpack counts matrix
#   N = lattice.N
#   # S = lattice.Nchange
#
#   # println("reaction = $(reaction)")
#
#   # sample a particle x of type i1 from the given class k
#   # println("attempt to sample $(i1) from class $(k)")
#   x = sample_from_class(lattice, s)
#
#   # sample a particle y of type i2 from x's neighborhood
#   # println("attempt to sample $(i2) from neighborhood of $(x)")
#   # println()
#   y = sample(neighborhood(x), i2, lattice.k2composition[get_neighbor_class(x)][i2])
#
#   #### this where we start ####
#   # k1old, k2old = get_neighbor_class(x), get_neighbor_class(y)
#   # l1old, l2old = get_ptype(x), get_ptype(y)
#   # N1old, N2old = N[k1old, l1old], N[k2old, l2old]
#
#   # we use up the particles (k1, i1) and (k2, i2)
#   N[get_neighbor_class(x), get_ptype(x)] -= 1
#   N[get_neighbor_class(y), get_ptype(y)] -= 1
#
#   # 1. change the types for x and y
#   i1 != j1 && transform!(x, j1)
#   i2 != j2 && transform!(y, j2)
#
#   # 2. update neighborhood and sample classes for x and y
#   update_classes_particle!(lattice, x, i1, j1, i2, j2)
#   update_classes_particle!(lattice, y, i2, j2, i1, j1)
#
#   # 3. update the remaining particles surrounding x and y
#   i1 != j1 && update_classes_neighbors!(lattice, x, y, i1, j1)
#   i2 != j2 && update_classes_neighbors!(lattice, y, x, i2, j2)
#
#   # k1new, k2new = get_neighbor_class(x), get_neighbor_class(y)
#   # l1new, l2new = get_ptype(x), get_ptype(y)
#   # N1new, N2new = N[k1new, l1new], N[k2new, l2new]
#
#   # we produced new particles so update the counts
#   N[get_neighbor_class(x), get_ptype(x)] += 1
#   N[get_neighbor_class(y), get_ptype(y)] += 1
#
#   # up to four changes may hav occurred:
#
#   # if N1old != N[k1old, l1old]
#   #   l1old != 1 && (S[k1old, l1old] = true)
#   # end
#
#   # if N1new != N[k1new, l1new]
#   #   l1new != 1 && (S[k1new, l1new] = true)
#   # end
#
#   # if N2old != N[k2old, l2old]
#   #   l2old != 1 && (S[k2old, l2old] = true)
#   # end
#
#   # if N2new != N[k2new, l2new]
#   #   l2new != 1 && (S[k2new, l2new] = true)
#   # end
#
#   return nothing
# end
#
# function execute_onsite!(lattice::SLattice, reaction)
#   # unpack reaction information
#   i, _ = get_reactant_types(reaction)
#   j, _ = get_product_types(reaction)
#   s = reaction.class
#
#   # unpack counts matrix
#   N = lattice.N
#   # S = lattice.Nchange
#
#   # sample a particle x of type i from the given class k
#   # println("attempt to sample $(i) from class $(k)")
#   x = sample_from_class(lattice, s)
#
#   # k_old, l_old = get_neighbor_class(x), get_ptype(x)
#   # N_old = N[k_old, l_old]
#
#   # we use up the x particle
#   N[get_neighbor_class(x), get_ptype(x)] -= 1
#
#   # 1. change the type for x
#   transform!(x, j)
#
#   # 2. update neighborhood and sample classes for x and y
#   update_classes_particle!(lattice, x, i, j, 0, 0)
#
#   # 3. update the remaining particles surrounding x and y
#   update_classes_neighbors!(lattice, x, x, i, j)
#
#   # k_new, l_new = get_neighbor_class(x), get_ptype(x)
#   # N_new = N[k_new, l_new]
#
#   # update the counts
#   N[get_neighbor_class(x), get_ptype(x)] += 1
#
#   # if N_old != N[k_old, l_old]
#   #   l_old != 1 && (S[k_old, l_old] = true)
#   # end
#
#   # if N_new != N[k_new, l_new]
#   #   l_new != 1 && (S[k_new, l_new] = true)
#   # end
#
#   return nothing
# end
#
# function rate(reaction::IPSReactionStruct, lattice::SLattice)
#   # grab reactant indices
#   l1, l2 = get_reactant_types(reaction)
#   s = reaction.class
#
#   # grab per particle rate
#   per_particle_rate = reaction.rate
#
#   # grab the count for the center particle
#   N_s = length(lattice.classes[s].members) # need to fix this
#
#   return N_s * per_particle_rate
# end
#
# ##### NLattice subroutines #####
#
# function execute_pairwise!(lattice::NLattice, reaction)
#   # unpack reaction information
#   i1, i2 = get_reactant_types(reaction)
#   j1, j2 = get_product_types(reaction)
#   k = reaction.class
#
#   # unpack counts matrix
#   N = lattice.N
#
#   # println("reaction = $(reaction)")
#
#   # sample a particle x of type i1 from the given class k
#   # composition = lattice.k2composition[k]
#   # println("  attempt to sample $(i1) from neighborhood class $(k) / $(composition)")
#   x = sample_center(lattice, i1, k)
#   # println("    got $(x)")
#   # sample a particle y of type i2 from x's neighborhood
#   # kx = get_neighbor_class(x)
#   # composition = lattice.k2composition[kx]
#   # println("  attempt to sample $(i2) from neighborhood class $(kx) / $(composition)")
#
#   y = sample(neighborhood(x), i2, lattice.k2composition[k][i2])
#
#   # println("    got $(y)")
#   # println()
#
#   # we use up the particles (k1, i1) and (k2, i2)
#   N[get_neighbor_class(x), get_ptype(x)] -= 1
#   N[get_neighbor_class(y), get_ptype(y)] -= 1
#
#   # if the type of center particle changed...
#   if i1 != j1
#     # update the class of its neighbors
#     # lost type i1 that became type j1
#     update_neighbor_classes!(lattice, x, y, i1, j1)
#   end
#
#   # if the type of the neighboring particle changed...
#   if i2 != j2
#     # update the class of its neighbors
#     # lost type i2 that became type j2
#     update_neighbor_classes!(lattice, y, x, i2, j2)
#   end
#
#   # change states
#   transform!(x, j1)
#   transform!(y, j2)
#
#   # we produced new particles so update the counts
#   N[get_neighbor_class(x), get_ptype(x)] += 1
#   N[get_neighbor_class(y), get_ptype(y)] += 1
#
#   return nothing
# end
#
# function execute_onsite!(lattice::NLattice, reaction)
#   # unpack reaction information
#   i, _ = get_reactant_types(reaction)
#   j, _ = get_product_types(reaction)
#   k = reaction.class
#
#   # unpack counts matrix
#   N = lattice.N
#
#   # sample a particle x of type i from the given class k
#   # println("attempt to sample $(i) from class $(k)")
#   x = sample_center(lattice, i, k)
#
#   # we use up the x particle
#   N[get_neighbor_class(x), get_ptype(x)] -= 1
#
#   # we might need this later if we model some complicated internal state
#   # # if the type of center particle changed...
#   # if i != j
#   #   # update the class of its neighbors
#   #   # lost type i1 that became type j1
#   #   update_neighbor_classes!(lattice, x, i, j)
#   # end
#
#   # for now, we assume i != j
#   update_neighbor_classes!(lattice, x, x, i, j)
#
#   # change states
#   transform!(x, j)
#
#   # update the counts
#   N[get_neighbor_class(x), get_ptype(x)] += 1
#
#   return nothing
# end
#
# function rate(reaction::IPSReactionStruct, lattice::NLattice)
#   # grab reactant indices
#   l1, l2 = get_reactant_types(reaction)
#   k = reaction.class # neighbor class!
#
#   # grab per particle rate
#   per_particle_rate = reaction.rate
#
#   # grab the count for the center particle
#   N_kl = lattice.N[k, l1]
#
#   return N_kl * per_particle_rate
# end
#
# ##### convenience wrapper
# rate(model::InteractingParticleSystem, lattice, j) = rate(model.reactions[j], lattice)
#
# ##### dependency graphs #####
#
# affect(rxn) = (rxn.input1, rxn.class)
#
# # determine the types affected by a reaction
# affected_types(rxn) = unique(setdiff([rxn.input1, rxn.input2, rxn.output1, rxn.output2], [0, 1]))
#
# # enumerate the AffectedBy
# function affected_by(rxn, sample_class, number_classes)
#   # determine the types that can change
#   affected_by_set = Tuple{Int,Int}[]
#
#   for x in affected_types(rxn)
#     for s in 1:number_classes
#       for s_star in sample_class[(x, s)]
#         affected_by_set = union(affected_by_set, [(x, s_star)])
#       end
#     end
#   end
#
#   return affected_by_set
# end
#
# count_pairwise(pairs) = count(x -> x[2] != 0, pairs)
# count_onsite(pairs) = count(x -> x[2] == 0, pairs)
#
# function rxnrxn_depgraph(::Iter, reaction::Vector{IPSReactionStruct}, isactive, enumeration) where Iter <: DGIterStyle
#   number_reactions = length(reaction)
#
#   # determine the set of particle types
#   ptypes = [ptype for rxn in reaction for ptype in (rxn.input1, rxn.input2, rxn.output1, rxn.output2)] |> unique
#
#   # determine reactant pairs
#   reactant_pairs = build_reactant_pairs(reaction)
#
#   # count the number of unique particle types and neighborhood capacity
#   L = setdiff(ptypes, [0, 1]) |> length
#
#   ##### absolutely dirty hack
#   nbmax = 0; rxn = reaction[nbmax+=1]
#
#   search_tuple = (rxn.input1, rxn.input2, rxn.output1, rxn.output2)
#   current_tuple = (rxn.input1, rxn.input2, rxn.output1, rxn.output2)
#
#   while current_tuple == search_tuple
#     rxn = reaction[nbmax+=1]
#     current_tuple = (rxn.input1, rxn.input2, rxn.output1, rxn.output2)
#   end
#
#   # build the sample classes
#   pair2class = enumeration.reactant_to_class
#   compositions = enumeration.composition
#   sample_class = enumeration.pair_to_classes
#
#   # count the number of sample classes
#   number_classes = nbmax * count_pairwise(reactant_pairs) + count_onsite(reactant_pairs)
#
#   # build the dependency graph
#   deps_range = Vector{Tuple{Int,Int}}(undef, number_reactions)
#   deps_value = Int[]
#
#   idx = 1
#   for j in eachindex(reaction)
#     affected_by_j = affected_by(reaction[j], sample_class, number_classes)
#     start = idx
#
#     for k in eachindex(reaction)
#       affect_k = affect(reaction[k])
#
#       if affect_k in affected_by_j
#         push!(deps_value, k)
#         idx += 1
#       end
#     end
#     stop = idx - 1
#
#     deps_range[j] = (start, stop)
#   end
#
#   return DGVector{Iter}(deps_range, deps_value)
# end