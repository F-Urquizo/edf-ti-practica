// Prueba del servidor sin Claude: lo arranca por stdio, lista las herramientas y llama a cada una.
// Uso: npm test   (desde herramientas/mcp-inventario/)
import assert from "node:assert/strict";
import { fileURLToPath } from "node:url";
import { Client } from "@modelcontextprotocol/sdk/client/index.js";
import { StdioClientTransport } from "@modelcontextprotocol/sdk/client/stdio.js";

const servidor = fileURLToPath(new URL("./index.js", import.meta.url));
const transporte = new StdioClientTransport({ command: process.execPath, args: [servidor], stderr: "ignore" });
const cliente = new Client({ name: "prueba", version: "1.0.0" });
await cliente.connect(transporte);

let fallas = 0;
async function caso(nombre, fn) {
  try {
    await fn();
    console.log(`ok    ${nombre}`);
  } catch (e) {
    fallas++;
    console.log(`FALLA ${nombre}\n      ${e.message}`);
  }
}

async function llama(name, args) {
  const r = await cliente.callTool({ name, arguments: args });
  return { error: r.isError === true, texto: r.content[0].text };
}
const datos = async (name, args) => JSON.parse((await llama(name, args)).texto);

await caso("expone exactamente 2 herramientas", async () => {
  const { tools } = await cliente.listTools();
  assert.deepEqual(tools.map((t) => t.name).sort(), ["buscar_servidor", "servidores_por"]);
  for (const t of tools) {
    assert.ok(t.description.length > 80, `${t.name} necesita una descripción clara`);
    assert.equal(t.annotations?.readOnlyHint, true, `${t.name} debe ser de solo lectura`);
  }
});

await caso("buscar_servidor: «prod» encuentra los 7 de producción", async () => {
  const r = await datos("buscar_servidor", { texto: "prod" });
  assert.equal(r.total, 7);
});

await caso("buscar_servidor: sin acentos ni mayúsculas («PRODUCCIÓN»)", async () => {
  const r = await datos("buscar_servidor", { texto: "PRODUCCIÓN" });
  assert.equal(r.total, 7);
});

await caso("buscar_servidor: «nginx» encuentra srv-web-qa-01", async () => {
  const r = await datos("buscar_servidor", { texto: "nginx" });
  assert.deepEqual(r.servidores.map((s) => s.nombre), ["srv-web-qa-01"]);
});

await caso("buscar_servidor: sin resultados devuelve total 0", async () => {
  const r = await datos("buscar_servidor", { texto: "no-existe-xyz" });
  assert.equal(r.total, 0);
});

await caso("servidores_por sistema_operativo, sin valor: conteo por grupo", async () => {
  const r = await datos("servidores_por", { campo: "sistema_operativo" });
  assert.equal(r.total_servidores, 10);
  const conteo = Object.fromEntries(r.grupos.map((g) => [g.valor, g.cantidad]));
  assert.deepEqual(conteo, {
    "RHEL 9.2": 3,
    "Debian 12": 2,
    "Ubuntu 22.04 LTS": 2,
    "RHEL 8.8": 1,
    "Ubuntu 20.04 LTS": 1,
    "Windows Server 2022": 1,
  });
});

await caso("servidores_por entorno=produccion: 7", async () => {
  const r = await datos("servidores_por", { campo: "entorno", valor: "produccion" });
  assert.equal(r.total, 7);
});

await caso("servidores_por sistema_operativo=rhel: 4 (9.2 y 8.8)", async () => {
  const r = await datos("servidores_por", { campo: "sistema_operativo", valor: "rhel" });
  assert.equal(r.total, 4);
});

await caso("servidores_por con un campo que no existe: error de validación", async () => {
  const r = await llama("servidores_por", { campo: "ip", valor: "10.0.0.1" });
  assert.equal(r.error, true);
});

await cliente.close();
console.log(fallas ? `\n${fallas} prueba(s) fallaron` : "\nTodas las pruebas pasaron");
process.exit(fallas ? 1 : 0);
