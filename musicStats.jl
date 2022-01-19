using DataStructures
using Plots
using JSON
using DataStructures
using HTTP
using JSON3

hist1 = Dict()
hist2 = Dict()
library = Dict()
tracks = Any[]
allHistTracks = Any[]
combinedTracks = Any[]
librarySongs = Any[]

# Open files and put into proper dicts
open("StreamingHistory0.json", "r") do f
    global hist1
    dicttxt = read(f,String)  # file information to string
    hist1=JSON.parse(dicttxt)  # parse and transform data
end

open("StreamingHistory1.json", "r") do f
    global hist2
    dicttxt = read(f,String)  # file information to string
    hist2=JSON.parse(dicttxt)  # parse and transform data
end

open("YourLibrary.json", "r") do f
    global library
    dicttxt = read(f,String)  # file information to string
    library=JSON.parse(dicttxt)  # parse and transform data
end

for track in hist2
    push!(tracks, track["trackName"])
end

# combine hist1 and hist2
for track in hist1
    push!(tracks, track["trackName"])
end

# create Array for all Library songs
for track in library["tracks"]
    push!(librarySongs, [track["track"],track["uri"]])
end

# count instances of each song in history
c = counter(tracks)
b = hcat([[key, val] for (key, val) in c])

historySorted =sort!(b, dims = 1, by = x -> x[2])

# Get top 10 songs, put in array
topTracks = Any[]
x = length(historySorted) - 20
while x <= length(historySorted)
    push!(topTracks, historySorted[x])
    global x += 1
end

# arrays to seperate title and count
topTrackTitleOverall = String[]
playCountOverall = Int64[]
for title in topTracks
    push!(topTrackTitleOverall, title[1])
    push!(playCountOverall, title[2])
end

allHistCombined = Dict(zip(topTrackTitleOverall, playCountOverall))
plot1 = bar(collect(keys(allHistCombined)), collect(values(allHistCombined)), orientation=:horizontal, yticks = :all, ytickfontsize=5)

# math for second graph, genres of top songs
# seperate top track names so they can be matched
tracklist = Any[]
for tracks in topTracks
    push!(tracklist, tracks[1])
end

# put top song uris in array to send later
topTrackUri = Any[]
for track in library["tracks"]
    if track["track"] in tracklist
        code = track["uri"]
        push!(topTrackUri, code[15:end])
    end
end

# generate spotify auth token
response = HTTP.post("https://accounts.spotify.com/api/token", 
    [
    "Authorization" => "Basic OTMyN2U5NTY2ZGI4NDRlNDg3MGRjNTVkZGY5Mjg2MTA6NjgwZmM4YmU5MzA2NDU2NGJlYTRlZTA4ODE0OTU4NmY=", 
    "Accept" => "*/*", 
    "Content-Type" => "application/x-www-form-urlencoded"
    ],"grant_type=client_credentials")

    # parse response
response_text = String(response.body)
s =JSON.parse(response_text)
token = s["access_token"]

# send song uri to get artist id
artistList = Any[]
for song in topTrackUri
    # global songString
    # songString = songString * "%2C" * song
    global getArtist
    global songResponse
    global songInfoParsed
    global fullUri
    getArtist = HTTP.get("https://api.spotify.com/v1/tracks/$song", 
    [
    "Authorization" => "Bearer $token", 
    "Accept" => "Accept: application/json", 
    "Content-Type" => "Accept: application/json"
    ])

    songResponse = String(getArtist.body)
    songInfoParsed =JSON.parse(songResponse)
    fullUri = songInfoParsed["album"]["artists"][1]["uri"]
    push!(artistList, fullUri[16:end])
end

# send artist id to get genre id
genres = Any[]
for uri in artistList
    global getGenre
    global artistResponse
    global artistInfoParsed
    getGenre = HTTP.get("https://api.spotify.com/v1/artists/$uri", 
        [
        "Authorization" => "Bearer $token", 
        "Accept" => "Accept: application/json", 
        "Content-Type" => "Accept: application/json"
        ])
        artistResponse = String(getGenre.body)
        artistInfoParsed =JSON.parse(artistResponse)
        if !isempty(artistInfoParsed["genres"])
            push!(genres, artistInfoParsed["genres"][1])
        end
end

# count the occurence of the genres
c = counter(genres)
b = hcat([[key, val] for (key, val) in c])

# sort low to high
sortedTracks =sort!(b, dims = 1, by = x -> x[2])

topTrackTitle = String[]
playCount = Int64[]
for title in sortedTracks
    push!(topTrackTitle, title[1])
    push!(playCount, title[2])
end

combined = Dict(zip(topTrackTitle, playCount))
plot2 = bar(collect(keys(combined)), collect(values(combined)), orientation=:horizontal, yticks = :all, ytickfontsize=5)

savefig(plot1,"plot1.png")
savefig(plot2,"plot2.png")

# cobine graphs on one canvas
plot!(plot1, plot2, layout = (2, 1), legend = false)
