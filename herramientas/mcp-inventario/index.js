#!/usr/bin/env node
// Servidor MCP de solo lectura sobre docs/inventario-servidores.csv.
// Transporte: stdio. Claude Code lo arranca como proceso local:
//   claude mcp add inventario-csv --scope project -- node herramientas/mcp-inventario/index.js
//
// Reglas:
// - Nada escribe: solo lee el CSV en cada llamada (si el inventario cambia, la respuesta cambia).
// - stdout es el canal del protocolo. Cualquier mensaje para personas va a stderr (console.error).

import { readFile } from "node:fs/promises";
import { fileURLToPath } from "node:url";
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";

// La ruta sale de la ubicación de este archivo, no de la carpeta desde donde se arranca.
const RUTA_CSV =
  process.env.INVENTARIO_CSV ||
  fileURLToPath(new URL("../../docs/inventario-servidores.csv", import.meta.url));

const CAMPOS = ["nombre", "rol", "sistema_operativo", "entorno", "responsable"];

// Minúsculas y sin acentos: "Producción" y "produccion" coinciden.
function normaliza(texto) {
  return String(texto).normalize("NFD").replace(/\p{M}/gu, "").toLowerCase().trim();
}

// CSV simple con soporte para comillas dobles y finales de línea CRLF (Windows).
function parseaCsv(contenido) {
  const filas = [];
  let fila = [];
  let campo = "";
  let enComillas = false;
  for (let i = 0; i < contenido.length; i++) {
    const c = contenido[i];
    if (enComillas) {
      if (c === '"' && contenido[i + 1] === '"') { campo += '"'; i++; }
      else if (c === '"') { enComillas = false; }
      else { campo += c; }
    } else if (c === '"') { enComillas = true; }
    else if (c === ",") { fila.push(campo); campo = ""; }
    else if (c === "\n" || c === "\r") {
      if (c === "\r" && contenido[i + 1] === "\n") i++;
      fila.push(campo); campo = "";
      if (fila.some((v) => v !== "")) filas.push(fila);
      fila = [];
    } else { campo += c; }
  }
  fila.push(campo);
  if (fila.some((v) => v !== "")) filas.push(fila);
  return filas;
}

async function leeInventario() {
  const contenido = await readFile(RUTA_CSV, "utf8");
  const [encabezados, ...filas] = parseaCsv(contenido.replace(/^﻿/, ""));
  const faltan = CAMPOS.filter((c) => !encabezados.includes(c));
  if (faltan.length) {
    throw new Error(`El CSV no tiene las columnas esperadas: falta ${faltan.join(", ")}`);
  }
  return filas.map((f) => Object.fromEntries(encabezados.map((h, i) => [h, (f[i] ?? "").trim()])));
}

function respuesta(datos) {
  return { content: [{ type: "text", text: JSON.stringify(datos, null, 2) }] };
}

function error(mensaje) {
  return { isError: true, content: [{ type: "text", text: mensaje }] };
}

const server = new McpServer({ name: "inventario-csv", version: "1.0.0" });

server.registerTool(
  "buscar_servidor",
  {
    title: "Buscar servidor en el inventario",
    description:
      "Busca servidores en el inventario de TI (docs/inventario-servidores.csv) por texto libre. " +
      "Revisa todas las columnas: nombre, rol, sistema_operativo, entorno y responsable. " +
      "Coincidencia parcial, sin distinguir mayúsculas ni acentos. " +
      "Úsala cuando pregunten por un servidor concreto o por una palabra (por ejemplo «db-prod», «nginx», «respaldos»). " +
      "Para listar o contar servidores por una columna, usa servidores_por. Solo lectura.",
    inputSchema: {
      texto: z
        .string()
        .min(1)
        .max(100)
        .describe("Texto a buscar, por ejemplo «srv-app», «postgres» o «Infraestructura»."),
    },
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async ({ texto }) => {
    try {
      const buscado = normaliza(texto);
      const servidores = (await leeInventario()).filter((s) =>
        CAMPOS.some((c) => normaliza(s[c]).includes(buscado)),
      );
      return respuesta({ texto, total: servidores.length, servidores });
    } catch (e) {
      return error(`No se pudo leer el inventario: ${e.message}`);
    }
  },
);

server.registerTool(
  "servidores_por",
  {
    title: "Servidores por columna",
    description:
      "Filtra o agrupa los servidores del inventario de TI por una columna. " +
      "Con campo y valor: devuelve los servidores cuyo campo contiene ese valor " +
      "(parcial, sin distinguir mayúsculas ni acentos; «RHEL» encuentra «RHEL 9.2» y «RHEL 8.8»). " +
      "Solo con campo, sin valor: devuelve cuántos servidores hay por cada valor de esa columna. " +
      "Úsala para preguntas como «¿cuántos servidores hay por sistema operativo?», " +
      "«¿qué servidores son de producción?» o «¿de qué servidores es responsable Infraestructura?». Solo lectura.",
    inputSchema: {
      campo: z
        .enum(CAMPOS)
        .describe("Columna del inventario: nombre, rol, sistema_operativo, entorno o responsable."),
      valor: z
        .string()
        .min(1)
        .max(100)
        .optional()
        .describe("Valor a buscar en esa columna. Omítelo para obtener el conteo por cada valor."),
    },
    annotations: { readOnlyHint: true, openWorldHint: false },
  },
  async ({ campo, valor }) => {
    try {
      const inventario = await leeInventario();
      if (valor === undefined) {
        const grupos = new Map();
        for (const s of inventario) {
          const clave = s[campo] || "(vacío)";
          if (!grupos.has(clave)) grupos.set(clave, []);
          grupos.get(clave).push(s.nombre);
        }
        return respuesta({
          campo,
          total_servidores: inventario.length,
          grupos: [...grupos]
            .map(([v, nombres]) => ({ valor: v, cantidad: nombres.length, servidores: nombres }))
            .sort((a, b) => b.cantidad - a.cantidad || a.valor.localeCompare(b.valor)),
        });
      }
      const buscado = normaliza(valor);
      const servidores = inventario.filter((s) => normaliza(s[campo]).includes(buscado));
      return respuesta({ campo, valor, total: servidores.length, servidores });
    } catch (e) {
      return error(`No se pudo leer el inventario: ${e.message}`);
    }
  },
);

await server.connect(new StdioServerTransport());
console.error(`mcp-inventario: listo, leyendo ${RUTA_CSV}`);
