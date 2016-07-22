"""
```
simulate(m::Newtork; method=:SSA, time=1.0, output=:explicit, sampling_interval=1.0, realizations=1, kwargs...)
```

### Arguments
- `m`: The network object

### Optional Arguments
- `method`: The algorithm used in the simulation.
- `time`: The stopping time for the simulation.
- `output`: The type of output to record. The `:explicit` option will record simulation history after every algorithm step, whereas `:fixed` will record the history after according to `sampling_interval`.
- `sampling_interval`: The time between updates when `output=:fixed`. The default is to record after every unit of time, according to the scale implicit in a given model `m`.
- `realizations`: The number of Monte Carlo realizations.
- `kwargs`: Optional keyword arguments specific to a particular algorithm. Refer to the appropriate algorithm for details.
"""
function simulate(network::Network; method::Symbol=:SSA, time=1.0, output=:fixed, sampling_interval=1.0, realizations=1, track=Symbol[], kwargs...)

  if method == :SSA
    algorithm = ssa(time; kwargs...)
  elseif method == :ODM
    algorithm = odm(time; kwargs...)
  elseif method == :FRM
    algorithm = frm(time; kwargs...)
  elseif method == :NRM
    algorithm = nrm(time; kwargs...)
  elseif method == :SAL
    algorithm = sal(time; kwargs...)
  else
    error("$method is an unrecognized algorithm.")
  end

  otype = (output == :explicit) ? Explicit() : Uniform()

  # Create the main data structure used in the simulation
  Xt, species_id, id2ind = make_species_arr(species_list(network))
  rs = reaction_system(reaction_list(network), id2ind)
  reaction_id = Symbol[]

  m = Model(network.id, Xt, rs, parameter_list(network), deepcopy(Xt))

  # Identify which objects to track
  if isempty(track)
      tracked_species = [ i for i in 1:length(species_id) ]
      tracked_reactions = Int[]
  else
      tracked_species   = findin(species_id, track)
      tracked_reactions = findin(reaction_id, track)
  end

  # Create the respective observers
  n = round(Int, time / sampling_interval) + 1
  tracker = make_observers(otype,
                            species_id,
                            tracked_species,
                            reaction_id,
                            tracked_reactions,
                            Xt,
                            rs,
                            n,
                            realizations)

  manager = init_updater(otype, tracker, sampling_interval, n, realizations) # Initialize update manager

  simulate(m, algorithm, otype, realizations, tracker, manager)
end

function simulate(m::Model, algorithm::Algorithm, output::OutputType, realizations, tracker, manager)
  initialize!(algorithm, m)

  Xt = m.Xt
  rs = m.rs
  p  = m.parameters
  X₀ = m.X₀

  for i = 1:realizations
    reset!(m)
    reset!(algorithm, m)
    while time(algorithm) < end_time(algorithm)
      update!(output, manager, time(algorithm))   # Record current state
      step!(algorithm, Xt, rs, p)
    end
    compute_statistics!(algorithm, i)
    final_update!(output, manager, time(algorithm)) # Record final state
  end

  sdata, pdata = compile_data(tracker)
  mdata = compile_metadata(algorithm, blocksize(manager), realizations, output)
  return SimulationOutput(sdata, pdata, mdata)
end
