import { Command } from "commander";
import { listAction } from "./commands/list.js";
import { swapAction } from "./commands/swap.js";
import { saveAction } from "./commands/save.js";

const program = new Command();

program
  .name("ff-profiles")
  .description("Manage Claude Code profiles")
  .version("1.0.0");

program
  .command("list")
  .description("List available profiles (built-in and custom)")
  .option("--repo-root <path>", "Path to the ff-profiles repo")
  .action((opts) => {
    listAction({ repoRoot: opts.repoRoot });
  });

program
  .command("swap <name>")
  .description("Apply a profile to the target directory")
  .option("--repo-root <path>", "Path to the ff-profiles repo")
  .option("--target <path>", "Target project directory")
  .action((name, opts) => {
    swapAction(name, { repoRoot: opts.repoRoot, target: opts.target });
  });

program
  .command("save <name>")
  .description("Save the current .claude/ directory as a custom profile")
  .option("--repo-root <path>", "Path to the ff-profiles repo")
  .option("--target <path>", "Target project directory")
  .option("--description <text>", "Description for saved profile")
  .option("--force", "Overwrite existing profile without prompting")
  .action((name, opts) => {
    saveAction(name, {
      repoRoot: opts.repoRoot,
      target: opts.target,
      description: opts.description,
      force: opts.force,
    });
  });

program
  .command("help")
  .description("Show help message")
  .allowUnknownOption()
  .action(() => {
    program.help();
  });

program.parse();
