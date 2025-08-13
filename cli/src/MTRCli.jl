module MTRCli

greet() = print("Hello World!")

using Comonicon
using MTR

"""
    Boilerplate function to install the Comonicon dependencies.
"""
@main function mtrcli(args)
    begin
        println("Hello, MTRCli!")
        if length(args) == 0
            println("No arguments provided.")
        else
            println("Arguments provided: ", args)
        end
    end
end

end # module MTRCli
