import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import YAML from "yaml";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const projectRoot = path.resolve(__dirname, "..");

const collectionRoot = path.join(projectRoot, "postman", "collections", "API Testing");
const environmentPath = path.join(projectRoot, "postman", "environments", "Test Subject 1.environment.yaml");
const outputRoot = path.join(projectRoot, "postman", "newman");
const collectionOutputPath = path.join(outputRoot, "API Testing.postman_collection.json");
const environmentOutputPath = path.join(outputRoot, "Test Subject 1.postman_environment.json");

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

function readYaml(filePath) {
  return YAML.parse(fs.readFileSync(filePath, "utf8"));
}

function requestNameFromFile(fileName) {
  return fileName.replace(/\.request\.yaml$/i, "");
}

function toPostmanUrl(url) {
  return {
    raw: url,
    host: [url]
  };
}

function toPostmanEvents(scripts = []) {
  return scripts.map((script) => ({
    listen: script.type === "beforeRequest" ? "prerequest" : "test",
    script: {
      type: "text/javascript",
      exec: String(script.code ?? "").replace(/\r\n/g, "\n").split("\n")
    }
  }));
}

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

fs.mkdirSync(outputRoot, { recursive: true });
fs.writeFileSync(collectionOutputPath, `${JSON.stringify(buildCollection(), null, 2)}\n`);
fs.writeFileSync(environmentOutputPath, `${JSON.stringify(buildEnvironment(), null, 2)}\n`);

console.log(`Generated ${path.relative(projectRoot, collectionOutputPath)}`);
console.log(`Generated ${path.relative(projectRoot, environmentOutputPath)}`);
