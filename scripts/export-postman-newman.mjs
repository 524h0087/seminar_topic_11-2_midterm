import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import YAML from "yaml";

// Absolute path of this script file (ES modules have no built-in __filename).
const __filename = fileURLToPath(import.meta.url);

// Directory containing this script (ES modules have no built-in __dirname).
const __dirname = path.dirname(__filename);
// seminar_topic_11-2_midterm

// Project root, used as the base for all other paths.
const projectRoot = path.resolve(__dirname, "..");
// seminar_topic_11-2_midterm/

// Source folder of the local Postman YAML collection.
const collectionRoot = path.join(projectRoot, "postman", "collections", "API Testing");
// seminar_topic_11-2_midterm/postman/collections/API Testing

// Source YAML file of the local Postman environment.
const environmentPath = path.join(projectRoot, "postman", "environments", "Test Subject 1.environment.yaml");
// seminar_topic_11-2_midterm/postman/environments/Test Subject 1.environment.yaml

// Output folder for the generated Newman-compatible JSON files.
const outputRoot = path.join(projectRoot, "postman", "newman");
// seminar_topic_11-2_midterm/postman/newman

// Output path of the generated Postman v2.1 collection JSON.
const collectionOutputPath = path.join(outputRoot, "API Testing.postman_collection.json");
// seminar_topic_11-2_midterm/postman/newman/API Testing.postman_collection.json

// Output path of the generated Postman environment JSON.
const environmentOutputPath = path.join(outputRoot, "Test Subject 1.postman_environment.json");
// seminar_topic_11-2_midterm/postman/newman/Test Subject 1.postman_environment.json

// Collection folders and their request files, in the order Newman should run them.
const folders = [
  {
    name: "01 - Health Test",
    requests: ["Health check.request.yaml"]
  },
  {
    name: "02 - Authorization Test",
    requests: ["Invalid Test.request.yaml", "Valid Login.request.yaml"]
  },
  {
    name: "03 - GET Test",
    requests: ["GET all students.request.yaml", "GET student by ID.request.yaml"]
  },
  {
    name: "04 - POST Test",
    requests: [
      "Create student.request.yaml",
      "Create student (Duplicate Email).request.yaml",
      "Create student (Invalid Email).request.yaml",
      "Create student (GPA Negative).request.yaml",
      "Create student (GPA Exceeded).request.yaml"
    ]
  },
  {
    name: "05 - PUT Test",
    requests: [
      "Update valid student.request.yaml",
      "Update Duplicate Email.request.yaml",
      "Update with Empty JSON.request.yaml"
    ]
  },
  {
    name: "06 - DELETE Test",
    requests: ["DELETE student.request.yaml"]
  }
];

// Reads a YAML file and returns its parsed contents.
function readYaml(filePath) {
  return YAML.parse(fs.readFileSync(filePath, "utf8"));
}

// Derives the request display name by stripping the ".request.yaml" suffix.
function requestNameFromFile(fileName) {
  return fileName.replace(/\.request\.yaml$/i, "");
}

// Wraps a raw URL string in the Postman collection URL object format.
function toPostmanUrl(url) {
  return {
    raw: url,
    host: [url]
  };
}

// Converts local YAML scripts into Postman pre-request/test events.
function toPostmanEvents(scripts = []) {
  return scripts.map((script) => ({
    listen: script.type === "beforeRequest" ? "prerequest" : "test",
    script: {
      type: "text/javascript",
      exec: String(script.code ?? "").replace(/\r\n/g, "\n").split("\n")
    }
  }));
}

// Converts a local YAML body into a Postman raw JSON body; only JSON is supported.
function toPostmanBody(body) {
  if (!body) {
    return undefined;
  }

  if (body.type !== "json") {
    throw new Error(`Unsupported Postman local body type: ${body.type}`);
  }

  return {
    mode: "raw",
    raw: body.content,
    options: {
      raw: {
        language: "json"
      }
    }
  };
}

// Builds a full Postman request item (method, headers, URL, body, scripts) from a request YAML file.
function toPostmanRequest(filePath) {
  const source = readYaml(filePath);
  const hasBody = Boolean(source.body);
  const header = hasBody
    ? [
        {
          key: "Content-Type",
          value: "application/json",
          type: "text"
        }
      ]
    : [];

  return {
    name: requestNameFromFile(path.basename(filePath)),
    request: {
      method: source.method,
      header,
      url: toPostmanUrl(source.url),
      body: toPostmanBody(source.body)
    },
    event: toPostmanEvents(source.scripts)
  };
}

// Assembles the Postman v2.1 collection with bearer auth and all folders/requests.
function buildCollection() {
  return {
    info: {
      name: "API Testing",
      description: "Generated from the local Postman YAML workspace for Newman automation.",
      schema: "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
    },
    auth: {
      type: "bearer",
      bearer: [
        {
          key: "token",
          value: "{{token}}",
          type: "string"
        }
      ]
    },
    item: folders.map((folder) => ({
      name: folder.name,
      item: folder.requests.map((requestFile) =>
        toPostmanRequest(path.join(collectionRoot, folder.name, requestFile))
      )
    }))
  };
}

// Builds the Postman environment JSON, forcing baseUrl to the local server address.
function buildEnvironment() {
  const source = readYaml(environmentPath);
  return {
    name: source.name,
    values: source.values.map((entry) => ({
      key: entry.key,
      value: entry.key === "baseUrl" ? "http://127.0.0.1:8080" : String(entry.value ?? ""),
      type: "default",
      enabled: true
    }))
  };
}

// Ensure the output folder exists, then write the generated collection and environment files.
fs.mkdirSync(outputRoot, { recursive: true });
fs.writeFileSync(collectionOutputPath, `${JSON.stringify(buildCollection(), null, 2)}\n`);
fs.writeFileSync(environmentOutputPath, `${JSON.stringify(buildEnvironment(), null, 2)}\n`);

console.log(`Generated ${path.relative(projectRoot, collectionOutputPath)}`);
console.log(`Generated ${path.relative(projectRoot, environmentOutputPath)}`);
