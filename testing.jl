using MIDI, CSV, DataFrames

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

function parse_midi_files(midi_dir::String, output_dir::String)
    # Get a list of all the MIDI files in the directory
    midi_files = find_midi_files(midi_dir)
    # Loop through the MIDI files and parse them
    for midi_file in midi_files
        # Parse the MIDI file
        midi_data = load(midi_file)

        # Initialize empty vectors to store the parsed data
        track = midi_data.tracks[2]

        notes = getnotes(track)
        noteNames = []
        velocities = []
        times = []

        # Loop through the MIDI events and extract the relevant data
        for note in notes
            push!(noteNames, note.pitch)
            push!(velocities, note.velocity)
            push!(times, note.duration)
        end

        # Construct a DataFrame from the parsed data
        df = DataFrame(
            note=noteNames,
            velocity=velocities,
            time=times
        )

        # Write the DataFrame to a CSV file
        csv_file = joinpath(output_dir, replace(basename(midi_file), ".mid" => ".csv"))
        CSV.write(csv_file, df)
    end
end

function reconstruct_midi_file(csv_file::String, midi_file::String)
    # Read the CSV file into a DataFrame
    df = CSV.read(csv_file, DataFrame)

    # Convert the parsed data into Note objects
    notes = Notes()
    time = 0
    for i in 1:size(df, 1)
        # Calculate the time since the last MIDI event
        delta_time = round(Int, df.time[i])

        # Create a Note object for the note-on event
        note = Note(df.note[i], df.velocity[i], time, delta_time)
        push!(notes, note)

        # Update the time counter
        time += delta_time
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
