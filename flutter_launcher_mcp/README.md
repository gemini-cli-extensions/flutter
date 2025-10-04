# flutter_launcher_mcp

An MCP server for launching and managing Flutter applications.

## Overview

`flutter_launcher_mcp` provides a Model Context Protocol (MCP) server that allows external clients (such as AI agents or IDEs) to programmatically launch Flutter applications and obtain their Dart Tooling Daemon (DTD) URI. It also provides a mechanism to gracefully terminate these launched processes.

This package aims to simplify the integration of Flutter development workflows with various tools by offering a standardized, language-agnostic interface for Flutter process management.

## Features

- **Launch Flutter Applications:** Start Flutter applications with custom arguments and retrieve their DTD URI.
- **Process Management:** Keep track of launched Flutter processes and terminate them when no longer needed.
- **Real-time DTD URI Retrieval:** Captures the DTD URI directly from the Flutter process's `stdout` stream.
- **MCP Compliant:** Exposes functionality via the Model Context Protocol for seamless integration with MCP-aware clients.
- **Testable Design:** Uses dependency injection for `ProcessManager` and `FileSystem` to facilitate unit testing.

## Installation

To use `flutter_launcher_mcp`, add it as a dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_launcher_mcp: ^0.2.2
```

Then, run `dart pub get`.

## Usage

### Running the MCP Server

The `flutter_launcher_mcp` package provides an executable that runs the MCP server. You can start it from your terminal:

```bash
dart run flutter_launcher_mcp
```

This will start the server, listening for MCP requests on standard input/output. Clients can then connect to this server using the `dart_mcp` client library or any other MCP-compliant client.

### Available Tools

The server exposes the following tools:

#### `launch_app`

Launches a Flutter application with specified arguments and returns its DTD URI and process ID.

- **Input Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "root": {
        "type": "string",
        "description": "The root directory of the Flutter project."
      },
      "target": {
        "type": "string",
        "description": "The main entry point file of the application. Defaults to \"lib/main.dart\"."
      },
      "device": {
        "type": "string",
        "description": "The device ID to launch the application on. To get a list of available devices to present as choices, use the list_devices tool."
      }
    },
    "required": ["root", "device"]
  }
  ```

- **Output Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "dtdUri": {
        "type": "string",
        "description": "The DTD URI of the launched Flutter application."
      },
      "pid": {
        "type": "integer",
        "description": "The process ID of the launched Flutter application."
      }
    },
    "required": ["dtdUri", "pid"]
  }
  ```

#### `hot_restart`

Performs a hot restart on a running Flutter application. This restarts the app while maintaining the current session.

- **Input Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "pid": {
        "type": "integer",
        "description": "The process ID of the flutter run process to hot restart."
      }
    },
    "required": ["pid"]
  }
  ```

- **Output Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "success": {
        "type": "boolean",
        "description": "Whether the hot restart was successful."
      }
    },
    "required": ["success"]
  }
  ```

#### `stop_app`

Kills a running Flutter process started by the `launch_app` tool.

- **Input Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "pid": {
        "type": "integer",
        "description": "The process ID of the process to kill."
      }
    },
    "required": ["pid"]
  }
  ```

- **Output Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "success": {
        "type": "boolean",
        "description": "Whether the process was killed successfully."
      }
    },
    "required": ["success"]
  }
  ```

#### `list_devices`

Lists available Flutter devices.

- **Input Schema:**

  ```json
  {
    "type": "object"
  }
  ```

- **Output Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "devices": {
        "type": "array",
        "description": "A list of available device IDs.",
        "items": {
          "type": "string"
        }
      }
    },
    "required": ["devices"]
  }
  ```

#### `get_app_logs`

Returns the collected logs for a given flutter run process id. Can only retrieve logs started by the `launch_app` tool.

- **Input Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "pid": {
        "type": "integer",
        "description": "The process ID of the flutter run process running the application."
      }
    },
    "required": ["pid"]
  }
  ```

- **Output Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "logs": {
        "type": "array",
        "description": "The collected logs for the process.",
        "items": {
          "type": "string"
        }
      }
    },
    "required": ["logs"]
  }
  ```

#### `list_running_apps`

Returns the list of running app process IDs and associated DTD URIs for apps started by the `launch_app` tool.

- **Input Schema:**

  ```json
  {
    "type": "object"
  }
  ```

- **Output Schema:**

  ```json
  {
    "type": "object",
    "properties": {
      "apps": {
        "type": "array",
        "description": "A list of running applications started by the launch_app tool.",
        "items": {
          "type": "object",
          "properties": {
            "pid": {
              "type": "integer",
              "description": "The process ID of the application."
            },
            "dtdUri": {
              "type": "string",
              "description": "The DTD URI of the application."
            }
          },
          "required": ["pid", "dtdUri"]
        }
      }
    },
    "required": ["apps"]
  }
  ```

## Development

### Running Tests

To run the unit tests for `flutter_launcher_mcp`:

```bash
dart test
```

### Code Formatting and Analysis

To format your code and run static analysis:

```bash
dart format .
dart fix --apply
dart analyze
```

## Contributing

Contributions are welcome! Please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

This project is licensed under the [LICENSE](LICENSE) file.
