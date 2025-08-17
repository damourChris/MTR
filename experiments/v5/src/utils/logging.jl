"""
Comprehensive logging system for CellTypeDeconvolutionFramework.

This module provides a sophisticated logging system with:
- Domain-based logging with configurable levels per domain
- File and console output with configurable formatting
- Integration with LocalPreferences.jl for persistent configuration
- Extensible domain registration system
- Macros that mimic Julia's built-in logging (@info, @warn, @debug, @error)

# Supported Domains

- `:io` - File I/O operations, data loading/saving
- `:preprocessing` - Data preprocessing and transformation operations
- `:calculation` - Mathematical computations, model training
- `:graph` - Graph operations and algorithms
- `:cache` - Caching operations and memory management
- `:evaluation` - Model evaluation and statistical testing
- `:configuration` - Configuration and preference management
- `:general` - General application logic and control flow

# Usage

```julia
using .Logging

# Configure logging preferences
configure_logging_preferences!(
    global_log_level = "info",
    enable_file_logging = true,
    log_directory_path = "logs",
    console_output_character_limit = 300
)

# Use domain-specific logging macros
@log_info :io "Loading reference dataset from file: {file_path}"
@log_warn :preprocessing "Missing values detected in expression matrix: {count} genes affected"
@log_error :calculation "Model training failed: {error_message}"
@log_debug :cache "Cache miss for key: {cache_key}"
```
"""

using Dates
using Preferences
using UUIDs

# Import preference management utilities from configuration module
# Note: These will be available when this module is included after preferences_management.jl

# =============================================================================
# LOGGING LEVEL DEFINITIONS
# =============================================================================

@enum LogLevel begin
    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3
end

# Convert string to LogLevel enum
function parse_log_level(level_string::AbstractString)::LogLevel
    level_lower = lowercase(strip(level_string))
    if level_lower == "debug"
        return DEBUG
    elseif level_lower == "info"
        return INFO
    elseif level_lower == "warn" || level_lower == "warning"
        return WARN
    elseif level_lower == "error"
        return ERROR
    else
        throw(
            ArgumentError(
                "Invalid log level: '$level_string'. Valid levels: debug, info, warn, error",
            ),
        )
    end
end

# Convert LogLevel enum to string
function log_level_to_string(level::LogLevel)::String
    if level == DEBUG
        return "DEBUG"
    elseif level == INFO
        return "INFO"
    elseif level == WARN
        return "WARN"
    elseif level == ERROR
        return "ERROR"
    end
end

# =============================================================================
# DOMAIN MANAGEMENT
# =============================================================================

# Predefined domains - extensible via register_logging_domain!
const REGISTERED_DOMAINS = Set{Symbol}([
    :io,
    :preprocessing,
    :calculation,
    :graph,
    :cache,
    :evaluation,
    :configuration,
    :general,
])

"""
    register_logging_domain!(domain::Symbol)

Register a new logging domain. This allows the logging system to accept
messages for the specified domain and apply domain-specific configuration.

# Arguments
- `domain`: Symbol representing the domain name (e.g., `:my_custom_domain`)

# Example
```julia
register_logging_domain!(:networking)
@log_info :networking "HTTP request completed successfully"
```
"""
function register_logging_domain!(domain::Symbol)
    push!(REGISTERED_DOMAINS, domain)
    @info "Registered new logging domain: $domain"
end

"""
    is_valid_domain(domain::Symbol)::Bool

Check if a domain is registered for logging.
"""
function is_valid_domain(domain::Symbol)::Bool
    return domain in REGISTERED_DOMAINS
end

# =============================================================================
# PREFERENCE MANAGEMENT
# =============================================================================

"""
    get_global_log_level()::LogLevel

Get the global log level from preferences. Defaults to INFO if not configured.
"""
function get_global_log_level()::LogLevel
    level_string = @load_framework_preference("logging_global_level", "info")
    return parse_log_level(level_string)
end

"""
    get_domain_log_level(domain::Symbol)::LogLevel

Get the log level for a specific domain. Falls back to global level if not configured.
"""
function get_domain_log_level(domain::Symbol)::LogLevel
    preference_key = "logging_domain_level_$(domain)"
    if @has_framework_preference(preference_key)
        level_string = @load_framework_preference(preference_key)
        return parse_log_level(level_string)
    else
        return get_global_log_level()
    end
end

"""
    is_file_logging_enabled()::Bool

Check if file logging is enabled in preferences. Defaults to true.
"""
function is_file_logging_enabled()::Bool
    return @load_framework_preference("logging_enable_file_output", true)
end

"""
    get_log_directory_path()::String

Get the directory path for log files. Defaults to "logs" in current directory.
"""
function get_log_directory_path()::String
    return @load_framework_preference("logging_directory_path", "logs")
end

"""
    get_console_output_character_limit()::Int

Get the maximum number of characters to display in console output. Defaults to 300.
"""
function get_console_output_character_limit()::Int
    return @load_framework_preference("logging_console_character_limit", 300)
end

"""
    is_console_logging_enabled()::Bool

Check if console logging is enabled. Defaults to true.
"""
function is_console_logging_enabled()::Bool
    return @load_framework_preference("logging_enable_console_output", true)
end

"""
    is_color_logging_enabled()::Bool

Check if color logging is enabled. Defaults to true.
"""
function is_color_logging_enabled()::Bool
    return @load_framework_preference("logging_enable_colors", true)
end

"""
    get_log_level_color(level::LogLevel)::String

Get the ANSI color code for a specific log level based on preferences.
"""
function get_log_level_color(level::LogLevel)::String
    if !is_color_logging_enabled()
        return ""
    end

    color_name = if level == DEBUG
        @load_framework_preference("logging_color_debug", "gray")
    elseif level == INFO
        @load_framework_preference("logging_color_info", "blue")
    elseif level == WARN
        @load_framework_preference("logging_color_warn", "yellow")
    elseif level == ERROR
        @load_framework_preference("logging_color_error", "red")
    else
        "default"
    end

    return get_ansi_color_code(color_name)
end

"""
    get_ansi_color_code(color_name::String)::String

Convert color name to ANSI color code.
"""
function get_ansi_color_code(color_name::String)::String
    color_lower = lowercase(strip(color_name))

    if color_lower == "black"
        return "\033[30m"
    elseif color_lower == "red"
        return "\033[31m"
    elseif color_lower == "green"
        return "\033[32m"
    elseif color_lower == "yellow"
        return "\033[33m"
    elseif color_lower == "blue"
        return "\033[34m"
    elseif color_lower == "magenta" || color_lower == "purple"
        return "\033[35m"
    elseif color_lower == "cyan"
        return "\033[36m"
    elseif color_lower == "white"
        return "\033[37m"
    elseif color_lower == "gray" || color_lower == "grey"
        return "\033[90m"  # Bright black (gray)
    elseif color_lower == "bright_red"
        return "\033[91m"
    elseif color_lower == "bright_green"
        return "\033[92m"
    elseif color_lower == "bright_yellow"
        return "\033[93m"
    elseif color_lower == "bright_blue"
        return "\033[94m"
    elseif color_lower == "bright_magenta"
        return "\033[95m"
    elseif color_lower == "bright_cyan"
        return "\033[96m"
    elseif color_lower == "bright_white"
        return "\033[97m"
    else
        return ""  # No color for unrecognized names
    end
end

"""
    get_ansi_reset_code()::String

Get the ANSI reset code to return to default colors.
"""
function get_ansi_reset_code()::String
    return "\033[0m"
end

# =============================================================================
# LOG FORMATTING
# =============================================================================

"""
    format_timestamp()::String

Create a formatted timestamp for log entries.
Returns format: "2024-08-16T14:30:45.123"
"""
function format_timestamp()::String
    return Dates.format(now(), "yyyy-mm-ddTHH:MM:SS.sss")
end

"""
    format_timestamp_console()::String

Create a reduced timestamp for console output to save space.
Returns format: "14:30:45" (time only, no date or milliseconds)
"""
function format_timestamp_console()::String
    return Dates.format(now(), "HH:MM:SS")
end

"""
    format_domain(domain::Symbol)::String

Format domain name for display in log messages.
Pads to consistent width for alignment.
"""
function format_domain(domain::Symbol)::String
    domain_str = string(domain)
    return rpad(uppercase(domain_str), 13)  # Pad to 13 characters for alignment
end

"""
    format_log_level(level::LogLevel)::String

Format log level for display with consistent width.
"""
function format_log_level(level::LogLevel)::String
    return rpad(log_level_to_string(level), 5)  # Pad to 5 characters
end

"""
    format_log_message(timestamp::String, domain::Symbol, level::LogLevel, message::String)::String

Create a formatted log message with timestamp, domain, level, and message.
Format: "2024-08-16T14:30:45.123 | IO           | INFO  | Loading dataset from file.csv"
"""
function format_log_message(
    timestamp::String,
    domain::Symbol,
    level::LogLevel,
    message::String,
)::String
    formatted_domain = format_domain(domain)
    formatted_level = format_log_level(level)
    return "$timestamp | $formatted_domain | $formatted_level | $message"
end

"""
    format_log_message_console(timestamp::String, domain::Symbol, level::LogLevel, message::String)::String

Create a formatted log message for console output with reduced timestamp and color support.
Format: "14:30:45 | IO           | INFO  | Loading dataset from file.csv"
Colors are applied to the entire line based on log level if color logging is enabled.
"""
function format_log_message_console(
    timestamp::String,
    domain::Symbol,
    level::LogLevel,
    message::String,
)::String
    formatted_domain = format_domain(domain)
    formatted_level = format_log_level(level)
    base_message = "$timestamp | $formatted_domain | $formatted_level | $message"

    # Add color if enabled
    if is_color_logging_enabled()
        color_code = get_log_level_color(level)
        reset_code = get_ansi_reset_code()
        return "$color_code$base_message$reset_code"
    else
        return base_message
    end
end

"""
    truncate_message_for_console(message::String, limit::Int)::String

Truncate message for console output if it exceeds the character limit.
Adds "..." to indicate truncation.
"""
function truncate_message_for_console(message::String, limit::Int)::String
    if length(message) <= limit
        return message
    else
        return message[1:(limit - 3)] * "..."
    end
end

# =============================================================================
# FILE LOGGING
# =============================================================================

"""
    ensure_log_directory_exists()

Create the log directory if it doesn't exist.
"""
function ensure_log_directory_exists()
    log_dir = get_log_directory_path()
    if !isdir(log_dir)
        mkpath(log_dir)
    end
end

"""
    get_log_file_path()::String

Get the path to the current log file.
Creates a daily log file: "framework_2024-08-16.log"
"""
function get_log_file_path()::String
    log_dir = get_log_directory_path()
    date_str = Dates.format(today(), "yyyy-mm-dd")
    filename = "framework_$date_str.log"
    return joinpath(log_dir, filename)
end

"""
    write_to_log_file(formatted_message::String)

Write a formatted message to the log file.
Creates the log directory and file if they don't exist.
"""
function write_to_log_file(formatted_message::String)
    if !is_file_logging_enabled()
        return
    end

    try
        ensure_log_directory_exists()
        log_file_path = get_log_file_path()

        open(log_file_path, "a") do file
            println(file, formatted_message)
        end
    catch e
        # Fallback to console if file logging fails
        println(stderr, "Failed to write to log file: $e")
        println(stderr, "Log message: $formatted_message")
    end
end

# =============================================================================
# CORE LOGGING FUNCTION
# =============================================================================

"""
    log_message(domain::Symbol, level::LogLevel, message::String)

Core logging function that handles both console and file output.
Checks log levels, formats messages, and routes to appropriate outputs.
Uses full timestamp for file logs and reduced timestamp for console output.
"""
function log_message(domain::Symbol, level::LogLevel, message::String)
    # Validate domain
    if !is_valid_domain(domain)
        @warn "Unknown logging domain: $domain. Use register_logging_domain!() to register new domains."
        return
    end

    # Check if message should be logged based on level
    domain_level = get_domain_log_level(domain)
    if level < domain_level
        return  # Message level is below threshold
    end

    # Format the complete message for file output (full timestamp)
    full_timestamp = format_timestamp()
    file_formatted_message = format_log_message(full_timestamp, domain, level, message)

    # Write to file
    write_to_log_file(file_formatted_message)

    # Write to console (with reduced timestamp and truncation if needed)
    if is_console_logging_enabled()
        console_timestamp = format_timestamp_console()
        console_formatted_message =
            format_log_message_console(console_timestamp, domain, level, message)

        console_limit = get_console_output_character_limit()
        console_message =
            truncate_message_for_console(console_formatted_message, console_limit)

        # Use appropriate output stream based on log level
        if level == ERROR
            println(stderr, console_message)
        else
            println(stdout, console_message)
        end
    end
end

# =============================================================================
# LOGGING MACROS
# =============================================================================

"""
    @log_debug domain message

Log a debug message for the specified domain.
Only outputs if domain log level is DEBUG or lower.

# Example
```julia
@log_debug :cache "Cache hit for key: user_123"
```
"""
macro log_debug(domain, message)
    return quote
        log_message($(esc(domain)), DEBUG, $(esc(message)))
    end
end

"""
    @log_info domain message

Log an info message for the specified domain.
Outputs if domain log level is INFO or lower.

# Example
```julia
@log_info :io "Successfully loaded dataset with 1000 samples"
```
"""
macro log_info(domain, message)
    return quote
        log_message($(esc(domain)), INFO, $(esc(message)))
    end
end

"""
    @log_warn domain message

Log a warning message for the specified domain.
Outputs if domain log level is WARN or lower.

# Example
```julia
@log_warn :preprocessing "Found 5 samples with missing expression values"
```
"""
macro log_warn(domain, message)
    return quote
        log_message($(esc(domain)), WARN, $(esc(message)))
    end
end

"""
    @log_error domain message

Log an error message for the specified domain.
Always outputs regardless of log level (ERROR is highest priority).

# Example
```julia
@log_error :calculation "Model training failed: insufficient memory"
```
"""
macro log_error(domain, message)
    return quote
        log_message($(esc(domain)), ERROR, $(esc(message)))
    end
end

# =============================================================================
# CONFIGURATION FUNCTIONS
# =============================================================================

"""
    configure_global_log_level!(level::String)

Set the global log level for all domains (unless overridden per domain).

# Arguments
- `level`: Log level as string ("debug", "info", "warn", "error")
"""
function configure_global_log_level!(level::String)
    # Validate level
    parse_log_level(level)  # This will throw if invalid
    set_framework_preference!("logging_global_level", level)
    @log_info :configuration "Global log level set to: $level"
end

"""
    configure_domain_log_level!(domain::Symbol, level::String)

Set the log level for a specific domain.

# Arguments
- `domain`: Domain symbol (e.g., `:io`, `:preprocessing`)
- `level`: Log level as string ("debug", "info", "warn", "error")
"""
function configure_domain_log_level!(domain::Symbol, level::String)
    # Validate inputs
    if !is_valid_domain(domain)
        throw(
            ArgumentError(
                "Domain $domain is not registered. Use register_logging_domain!() first.",
            ),
        )
    end
    parse_log_level(level)  # This will throw if invalid

    preference_key = "logging_domain_level_$(domain)"
    set_framework_preference!(preference_key, level)
    @log_info :configuration "Log level for domain $domain set to: $level"
end

"""
    configure_file_logging!(enabled::Bool, directory_path::String = "logs")

Configure file logging settings.

# Arguments
- `enabled`: Whether to enable file logging
- `directory_path`: Directory where log files will be stored
"""
function configure_file_logging!(enabled::Bool, directory_path::String = "logs")
    set_framework_preference!("logging_enable_file_output", enabled)
    set_framework_preference!("logging_directory_path", directory_path)

    status = enabled ? "enabled" : "disabled"
    @log_info :configuration "File logging $status with directory: $directory_path"
end

"""
    configure_console_logging!(enabled::Bool, character_limit::Int = 300)

Configure console logging settings.

# Arguments
- `enabled`: Whether to enable console logging
- `character_limit`: Maximum characters to display in console (prevents overflow)
"""
function configure_console_logging!(enabled::Bool, character_limit::Int = 300)
    if character_limit < 50
        throw(ArgumentError("Character limit must be at least 50 characters"))
    end

    set_framework_preference!("logging_enable_console_output", enabled)
    set_framework_preference!("logging_console_character_limit", character_limit)

    status = enabled ? "enabled" : "disabled"
    @log_info :configuration "Console logging $status with character limit: $character_limit"
end

"""
    configure_color_logging!(enabled::Bool, debug_color::String = "gray", info_color::String = "blue", 
                             warn_color::String = "yellow", error_color::String = "red")

Configure color logging settings.

# Arguments
- `enabled`: Whether to enable color logging
- `debug_color`: Color for debug messages (default: "gray")
- `info_color`: Color for info messages (default: "blue")
- `warn_color`: Color for warning messages (default: "yellow")
- `error_color`: Color for error messages (default: "red")

# Supported Colors
- Basic colors: black, red, green, yellow, blue, magenta, cyan, white, gray
- Bright colors: bright_red, bright_green, bright_blue, etc.
"""
function configure_color_logging!(
    enabled::Bool,
    debug_color::String = "gray",
    info_color::String = "blue",
    warn_color::String = "yellow",
    error_color::String = "red",
)
    set_framework_preference!("logging_enable_colors", enabled)
    set_framework_preference!("logging_color_debug", debug_color)
    set_framework_preference!("logging_color_info", info_color)
    set_framework_preference!("logging_color_warn", warn_color)
    set_framework_preference!("logging_color_error", error_color)

    status = enabled ? "enabled" : "disabled"
    @log_info :configuration "Color logging $status with scheme: DEBUG=$debug_color, INFO=$info_color, WARN=$warn_color, ERROR=$error_color"
end

"""
    configure_logging_preferences!(;
        global_log_level::String = "info",
        enable_file_logging::Bool = true,
        log_directory_path::String = "logs",
        enable_console_logging::Bool = true,
        console_character_limit::Int = 300,
        enable_colors::Bool = true,
        debug_color::String = "gray",
        info_color::String = "blue",
        warn_color::String = "yellow",
        error_color::String = "red"
    )

Convenience function to configure all logging preferences at once.
"""
function configure_logging_preferences!(;
    global_log_level::String = "info",
    enable_file_logging::Bool = true,
    log_directory_path::String = "logs",
    enable_console_logging::Bool = true,
    console_character_limit::Int = 300,
    enable_colors::Bool = true,
    debug_color::String = "gray",
    info_color::String = "blue",
    warn_color::String = "yellow",
    error_color::String = "red",
)
    configure_global_log_level!(global_log_level)
    configure_file_logging!(enable_file_logging, log_directory_path)
    configure_console_logging!(enable_console_logging, console_character_limit)
    configure_color_logging!(
        enable_colors,
        debug_color,
        info_color,
        warn_color,
        error_color,
    )

    @log_info :configuration "Logging system configured with global level: $global_log_level"
end

"""
    display_logging_configuration()

Display current logging configuration for debugging purposes.
"""
function display_logging_configuration()
    println("\n=== Logging Configuration ===")
    println("Global log level: $(log_level_to_string(get_global_log_level()))")
    println("File logging enabled: $(is_file_logging_enabled())")
    println("Log directory: $(get_log_directory_path())")
    println("Console logging enabled: $(is_console_logging_enabled())")
    println("Console character limit: $(get_console_output_character_limit())")
    println("Color logging enabled: $(is_color_logging_enabled())")
    if is_color_logging_enabled()
        debug_color = @load_framework_preference("logging_color_debug", "gray")
        info_color = @load_framework_preference("logging_color_info", "blue")
        warn_color = @load_framework_preference("logging_color_warn", "yellow")
        error_color = @load_framework_preference("logging_color_error", "red")
        println(
            "Color scheme: DEBUG=$debug_color, INFO=$info_color, WARN=$warn_color, ERROR=$error_color",
        )
    end
    println("Registered domains: $(sort(collect(REGISTERED_DOMAINS)))")

    # Show domain-specific levels if any are configured
    println("\nDomain-specific log levels:")
    for domain in sort(collect(REGISTERED_DOMAINS))
        preference_key = "logging_domain_level_$(domain)"
        if @has_framework_preference(preference_key)
            level = @load_framework_preference(preference_key)
            println("  $domain: $level")
        end
    end
    println("=============================\n")
end

# =============================================================================
# EXPORTS
# =============================================================================

export
    # Logging macros (main interface)
    @log_debug,
    @log_info,
    @log_warn,
    @log_error,

    # Configuration functions
    configure_logging_preferences!,
    configure_global_log_level!,
    configure_domain_log_level!,
    configure_file_logging!,
    configure_console_logging!,
    configure_color_logging!,

    # Domain management
    register_logging_domain!,
    is_valid_domain,

    # Utility functions
    display_logging_configuration,

    # Log levels (for advanced usage)
    LogLevel,
    DEBUG,
    INFO,
    WARN,
    ERROR
