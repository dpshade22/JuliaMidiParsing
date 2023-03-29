using MIDI, CSV, DataFrames, StatsBase, DataFramesMeta

function find_midi_files(directory::String)
    # Get a list of all the files and directories in the directory
    items = readdir(directory)

    # Initialize an empty vector to store the MIDI files
    midi_files = Vector{String}()

    # Loop through each item in the directory
    for item in items
        # Get the full path to the item
        item_path = joinpath(directory, item)

        # If the item is a directory, recursively search it for MIDI files
        if isdir(item_path)
            midi_files = vcat(midi_files, find_midi_files(item_path))
            # If the item is a MIDI file, add it to the list
        elseif endswith(item, ".mid") || endswith(item, ".midi")
            push!(midi_files, item_path)
        end
    end

    # Return the list of MIDI files
    return midi_files
end

function parse_midi_file(midi_file::String, output_dir::String)
    if midi_file[end] == '/'
        midi_file = midi_file[1:end-1]
    end

    # Parse the MIDI file
    midi_data = load(midi_file)

    # Initialize empty vectors to store the parsed data
    noteNames = []
    velocities = []
    positions = []
    durations = []

    for track in midi_data.tracks
        # Loop through the MIDI events and extract the relevant data
        notes = getnotes(track)
        for note in notes
            push!(noteNames, note.pitch)
            push!(velocities, note.velocity)
            push!(positions, note.position)
            push!(durations, note.duration)
        end
    end

    # Construct a DataFrame from the parsed data
    df = DataFrame(
        note=noteNames,
        velocity=velocities,
        position=positions,
        duration=durations
    )

    # Write the DataFrame to a CSV file
    csvName = replace(basename(midi_file)[1:end-4], "." => "_") * ".csv"
    csv_file = joinpath(output_dir, csvName)
    CSV.write(csv_file, df)
end

function parse_midi_files(midi_dir::String, output_dir::String)
    # Get a list of all the MIDI files in the directory
    midi_files = find_midi_files(midi_dir)
    midi_files = [replace(file, "\\" => "/") for file in midi_files]
    # Loop through the MIDI files and parse them
    for file in midi_files
        try
            parse_midi_file(file, output_dir)

        catch e
            println(e, file)
        end
    end
end


function reconstruct_midi_file(csv_file::String, midi_file::String)
    # Read the CSV file into a DataFrame
    df = CSV.read(csv_file, DataFrame)
    df = df[!, [:note, :velocity, :position, :duration]]
    # Convert the parsed data into Note objects
    notes = Notes()
    for i in 1:size(df, 1)
        # Calculate the time since the last MIDI event

        # Create a Note object for the note-on event
        note = Note(df.note[i], df.velocity[i], df.position[i], df.duration[i])
        push!(notes, note)

        # Update the time counter
    end

    # Create a MIDI track from the Note objects
    track = MIDITrack()
    addnotes!(track, notes)
    addtrackname!(track, "reconstructed track")

    # Create a MIDI file from the track
    file = MIDIFile()
    push!(file.tracks, track)
    writeMIDIFile(midi_file, file)
end

function add_synthetic_anomalies(csv_file::String, anomalous_dir::String, anomaly_percentage::Float64)
    # Load the CSV file into a DataFrame
    df = CSV.read(csv_file, DataFrame)

    # Add a column to track anomalies
    df.anomalies = zeros(Int64, size(df, 1))

    # Generate a matrix of deviations for each row
    num_anomalies = round(Int, size(df, 1) * anomaly_percentage)
    deviations = zeros(size(df))

    indices = sample(1:size(df, 1), num_anomalies, replace=false)

    # Generate random values for each column with the specified probability distributions
    for idx in indices
        deviations[idx, 1] = rand(vcat(-14:14, zeros(28)))
        deviations[idx, 2] = rand(vcat(-40:-20, zeros(40), 20:40))
        deviations[idx, 3] = rand(vcat(-500:-50, zeros(900), 50:500))
        deviations[idx, 4] = rand(vcat(-100:-50, zeros(1000), 50:1000))
    end

    # Apply the deviations to the selected rows using broadcasting
    df[indices, :] .= df[indices, :] .+ deviations[indices, :]

    # Use the map function to count non-zero elements in each row of the selected indices of deviations
    non_zero_counts = [length(findall(!iszero, row)) for row in eachrow(deviations[indices, :])]


    # Assign the non_zero_counts to the anomalies column of the df DataFrame at the specified indices

    df.anomalies[indices] .= non_zero_counts
    # Clamp the values between 0 and 127
    df[!, [:note, :velocity]] .= clamp.(df[!, [:note, :velocity]], 0, 127)
    df .= max.(df, 0)

    # Write the DataFrame to the anomalous directory
    csv_file_name = splitdir(csv_file)[end][1:end-4]
    csv_output_file = joinpath(anomalous_dir, "$csv_file_name" * "_" * "$anomaly_percentage.csv")

    CSV.write(csv_output_file, df)
end

function add_anomalous_data(csv_dir::String, anomalous_dir::String)
    csv_files = readdir(csv_dir)
    for csv_file in csv_files
        for anomaly_percentage in range(0.05; stop=0.95, step=0.05)
            add_synthetic_anomalies(joinpath(csv_dir, csv_file), anomalous_dir, anomaly_percentage)
        end
    end
end

# @time add_anomalous_data("assets/csvData", "assets/anomalous")

reconstruct_midi_file("assets/anomalous/[ajin_op]_yoru_wa_nemureru_kai_-__flumpool__fonzi_m__0.95.csv", "BAD.mid")
reconstruct_midi_file("assets/csvData/[ajin_op]_yoru_wa_nemureru_kai_-__flumpool__fonzi_m_.csv", "GOOD.mid")
