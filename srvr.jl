# Load required packages
using JuliaWebAPI
import EmmaServer: main


if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
