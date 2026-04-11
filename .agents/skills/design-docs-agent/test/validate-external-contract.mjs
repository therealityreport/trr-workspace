import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { createRequire } from "node:module";

const scriptDir = path.dirname(new URL(import.meta.url).pathname);
const packageRoot = path.resolve(scriptDir, "..");
const repoRoot = path.resolve(packageRoot, "..", "..", "..");
const appPackageJson = path.join(repoRoot, "TRR-APP", "apps", "web", "package.json");
const appRequire = createRequire(appPackageJson);
const ts = appRequire("typescript");
const YAML = appRequire("yaml");

function fail(message) {
  console.error(`[validate-external-contract] ${message}`);
  process.exit(1);
}

function readContract() {
  const contractPath = path.join(packageRoot, "contracts", "external-app-contract.yaml");
  return YAML.parse(fs.readFileSync(contractPath, "utf8"));
}

function readSourceFile(relativePath) {
  const filePath = path.join(repoRoot, relativePath);
  const sourceText = fs.readFileSync(filePath, "utf8");
  return {
    filePath,
    sourceFile: ts.createSourceFile(filePath, sourceText, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS),
  };
}

function collectExports(sourceFile) {
  const interfaces = new Map();
  const typeAliases = new Map();
  const consts = new Set();
  const functions = new Set();

  function isExported(node) {
    return Boolean(
      node.modifiers?.some((modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword),
    );
  }

  sourceFile.forEachChild((node) => {
    if (!isExported(node)) {
      return;
    }
    if (ts.isInterfaceDeclaration(node)) {
      interfaces.set(node.name.text, node);
      return;
    }
    if (ts.isTypeAliasDeclaration(node)) {
      typeAliases.set(node.name.text, node);
      return;
    }
    if (ts.isFunctionDeclaration(node) && node.name) {
      functions.add(node.name.text);
      return;
    }
    if (ts.isVariableStatement(node)) {
      for (const declaration of node.declarationList.declarations) {
        if (ts.isIdentifier(declaration.name)) {
          consts.add(declaration.name.text);
        }
      }
    }
  });

  return { interfaces, typeAliases, consts, functions };
}

function getUnionLiterals(typeNode) {
  if (!ts.isUnionTypeNode(typeNode)) {
    return [];
  }
  return typeNode.types
    .filter(ts.isLiteralTypeNode)
    .map((member) => member.literal)
    .filter(ts.isStringLiteral)
    .map((literal) => literal.text);
}

function getInterfaceFields(interfaceNode) {
  return interfaceNode.members
    .filter(ts.isPropertySignature)
    .map((member) => member.name)
    .filter(ts.isIdentifier)
    .map((name) => name.text);
}

function validatePipelineTypes(contract) {
  const spec = contract.files.pipeline_types;
  const { sourceFile } = readSourceFile(spec.path);
  const exports = collectExports(sourceFile);

  for (const interfaceName of spec.interfaces ?? []) {
    if (!exports.interfaces.has(interfaceName)) {
      fail(`missing exported interface '${interfaceName}' in ${spec.path}`);
    }
  }

  for (const [interfaceName, requiredFields] of Object.entries(spec.interface_field_requirements ?? {})) {
    const node = exports.interfaces.get(interfaceName);
    if (!node) {
      fail(`missing exported interface '${interfaceName}' for field validation in ${spec.path}`);
    }
    const fields = new Set(getInterfaceFields(node));
    for (const field of requiredFields) {
      if (!fields.has(field)) {
        fail(`missing field '${field}' on interface '${interfaceName}' in ${spec.path}`);
      }
    }
  }

  for (const [typeAliasName, requirements] of Object.entries(spec.type_aliases ?? {})) {
    const node = exports.typeAliases.get(typeAliasName);
    if (!node) {
      fail(`missing exported type alias '${typeAliasName}' in ${spec.path}`);
    }
    if (requirements.union_literals) {
      const literals = new Set(getUnionLiterals(node.type));
      for (const literal of requirements.union_literals) {
        if (!literals.has(literal)) {
          fail(`missing literal '${literal}' on type alias '${typeAliasName}' in ${spec.path}`);
        }
      }
    }
  }
}

function validateConfig(contract) {
  const spec = contract.files.design_docs_config;
  const { sourceFile } = readSourceFile(spec.path);
  const exports = collectExports(sourceFile);

  for (const constName of spec.consts ?? []) {
    if (!exports.consts.has(constName)) {
      fail(`missing exported const '${constName}' in ${spec.path}`);
    }
  }

  for (const functionName of spec.functions ?? []) {
    if (!exports.functions.has(functionName)) {
      fail(`missing exported function '${functionName}' in ${spec.path}`);
    }
  }

  for (const [typeAliasName, requirements] of Object.entries(spec.type_aliases ?? {})) {
    const node = exports.typeAliases.get(typeAliasName);
    if (!node) {
      fail(`missing exported type alias '${typeAliasName}' in ${spec.path}`);
    }
    if (requirements.union_literals) {
      const literals = new Set(getUnionLiterals(node.type));
      for (const literal of requirements.union_literals) {
        if (!literals.has(literal)) {
          fail(`missing literal '${literal}' on type alias '${typeAliasName}' in ${spec.path}`);
        }
      }
    }
  }
}

const contract = readContract();
validatePipelineTypes(contract);
validateConfig(contract);
console.log("[validate-external-contract] OK");
