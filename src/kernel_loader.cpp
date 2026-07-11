

//#include <Rcpp.h>
#include <RcppArmadillo.h>
#include "openclPort.h"

#include <fstream>
#include <sstream>
#include <string>
#include <filesystem>
#include <vector>
#include <map>
#include <set>
#include <unordered_map>
#include <unordered_set>
#include <stdexcept>
#include <algorithm>
#include <cctype>
#include <R.h>

namespace fs = std::filesystem;
using namespace openclPort;

namespace openclPort {

std::string load_kernel_source(const std::string& relative_path,
                               const std::string& package ) {
  std::string path = Rcpp::as<std::string>(
    Rcpp::Function("system.file")("cl", relative_path,
                   Rcpp::Named("package") = package)
  );

  if (path.empty()) {
    throw std::runtime_error("Kernel source not found via system.file: " + relative_path);
  }

  std::ifstream file(path);
  if (!file.is_open()) {
    throw std::runtime_error("Failed to open kernel source: " + path);
  }

  std::ostringstream oss;
  oss << file.rdbuf();
  return oss.str();
}

std::string load_kernel_library(const std::string& subdir, const std::string& package , bool verbose ) {
  std::string dir_path = Rcpp::as<std::string>(
    Rcpp::Function("system.file")("cl", subdir, Rcpp::Named("package") = package)
  );

  std::map<std::string, std::set<std::string>> provides_map;
  std::map<std::string, std::set<std::string>> depends_map;
  std::map<std::string, std::filesystem::path> file_map;

  if (verbose)  Rprintf("\n📂 Files found in '%s':\n", subdir.c_str());
  for (const auto& entry : std::filesystem::directory_iterator(dir_path)) {
    if (entry.path().extension() == ".cl") {
      std::string file_id = entry.path().stem().string();
      if (verbose) Rprintf(" - %s\n", file_id.c_str());

      std::ifstream infile(entry.path());
      std::string line;
      std::set<std::string> provides, depends;

      while (std::getline(infile, line)) {
        if (line.find("@provides") != std::string::npos) {
          std::stringstream ss(line.substr(line.find("@provides") + 9));
          std::string item;
          while (ss >> item) provides.insert(item);
        } else if (line.find("@depends") != std::string::npos) {
          std::stringstream ss(line.substr(line.find("@depends") + 9));
          std::string item;
          while (ss >> item) {
            item.erase(std::remove(item.begin(), item.end(), ','), item.end());
            depends.insert(item);
          }
        }
      }

      file_map[file_id] = entry.path();
      provides_map[file_id] = provides;
      depends_map[file_id] = depends;
    }
  }

  std::vector<std::string> sorted;
  std::set<std::string> sorted_set;
  std::set<std::string> unsorted_set;

  if (verbose)  Rprintf("\n📤 Files with no dependencies:\n");
  for (const auto& [file, _] : file_map) {
    if (depends_map[file].empty()) {
      sorted.push_back(file);
      sorted_set.insert(file);
      if (verbose) Rprintf(" + %s\n", file.c_str());
    } else {
      unsorted_set.insert(file);
    }
  }

  if (verbose)  Rprintf("\n🧪 Unsorted files:\n");
  for (const auto& file : unsorted_set) {
    if (verbose) Rprintf(" - %s\n", file.c_str());
  }

  int pass_count = 0;
  while (!unsorted_set.empty()) {
    ++pass_count;
    if (verbose) Rprintf("\n🔁 While Loop Pass #%d — Remaining unsorted: %d\n", pass_count, (int)unsorted_set.size());

    std::vector<std::string> newly_sorted;
    bool progress_made = false;
    int file_counter = 0;

    for (const std::string& file : unsorted_set) {
      ++file_counter;
      if (verbose) Rprintf("   🔍 File #%d: %s\n", file_counter, file.c_str());

      const auto& deps = depends_map[file];
      int depends_counter = static_cast<int>(deps.size());
      if (verbose) Rprintf("      📦 Dependency Count: %d\n", depends_counter);

      int found_counter = 0;
      int dep_index = 0;
      for (const std::string& dep : deps) {
        ++dep_index;
        if (verbose) Rprintf("         🔎 Checking classified #%d: %s\n", dep_index, dep.c_str());

        auto it = sorted_set.find(dep);
        if (it != sorted_set.end()) {
          if (verbose) Rprintf("            ➤ Found in sorted? ✅ Yes\n");
          ++found_counter;
        } else {
          if (verbose) Rprintf("            ➤ Found in sorted? ❌ No\n");
        }
      }

      if (verbose) Rprintf("      🔍 Found count: %d\n", found_counter);
      if (found_counter == depends_counter) {
        sorted.push_back(file);
        sorted_set.insert(file);
        newly_sorted.push_back(file);
        progress_made = true;
        if (verbose) Rprintf(" ✅ Promoted to Sorted: %s\n", file.c_str());
      }
    }

    for (const std::string& file : newly_sorted) {
      unsorted_set.erase(file);
    }

    if (!progress_made) {
      if (verbose) {
        Rprintf("\n❌ No files promoted on pass #%d; possible circular or missing dependencies:\n", pass_count);
        for (const std::string& file : unsorted_set) {
          Rprintf(" - %s\n", file.c_str());
        }
      }
      throw std::runtime_error("Dependency sort failed: unresolved dependencies remain.");
    }
  }

  if (verbose)  Rprintf("\n🔗 Final Sorted Load Order:\n");
  for (const auto& file : sorted) {
    if (verbose) Rprintf(" - %s\n", file.c_str());
  }

  std::string combined_source;
  for (const auto& file : sorted) {
    std::string rel_path = subdir + "/" + file + ".cl";
    combined_source += load_kernel_source(rel_path, package) + "\n";
  }

  return combined_source;
}

namespace {

std::vector<std::string> parse_cl_tag(
    const std::vector<std::string>& lines,
    const std::string& tag)
{
  std::vector<std::string> result;
  std::string pattern = "@" + tag;
  for (const auto& line : lines) {
    auto pos = line.find(pattern);
    if (pos == std::string::npos) continue;
    auto colon = line.find(':', pos + pattern.size());
    if (colon == std::string::npos) continue;
    std::istringstream ss(line.substr(colon + 1));
    std::string tok;
    while (std::getline(ss, tok, ',')) {
      tok.erase(0, tok.find_first_not_of(" \t\r\n"));
      auto last = tok.find_last_not_of(" \t\r\n");
      if (last != std::string::npos) tok.erase(last + 1);
      if (!tok.empty()) result.push_back(tok);
    }
  }
  return result;
}

struct KernelDepIndex {
  std::vector<std::string> stems_ordered;
  std::unordered_map<std::string, std::vector<std::string>> all_depends;
};

KernelDepIndex read_tsv_index(const std::string& tsv_path)
{
  KernelDepIndex idx;
  std::ifstream f(tsv_path);
  if (!f.is_open()) {
    throw std::runtime_error(
        "kernel_dependency_index.tsv not found: " + tsv_path);
  }
  std::string line;
  bool header = true;
  while (std::getline(f, line)) {
    if (header) { header = false; continue; }
    if (!line.empty() && line.back() == '\r') line.pop_back();
    if (line.empty()) continue;

    auto tab = line.find('\t');
    std::string stem = (tab == std::string::npos) ? line : line.substr(0, tab);
    if (stem.empty()) continue;
    idx.stems_ordered.push_back(stem);

    std::vector<std::string> deps;
    if (tab != std::string::npos && tab + 1 < line.size()) {
      std::istringstream ss(line.substr(tab + 1));
      std::string tok;
      while (std::getline(ss, tok, ',')) {
        tok.erase(0, tok.find_first_not_of(" \t\r\n"));
        auto last = tok.find_last_not_of(" \t\r\n");
        if (last != std::string::npos) tok.erase(last + 1);
        if (!tok.empty()) deps.push_back(tok);
      }
    }
    idx.all_depends[stem] = std::move(deps);
  }
  return idx;
}

} // namespace

std::string load_library_for_kernel(
    const std::string& kernel_relative_path,
    const std::string& library_subdir,
    const std::string& package,
    const std::string& depends_tag)
{
  std::string kernel_path = Rcpp::as<std::string>(
      Rcpp::Function("system.file")(
          "cl", kernel_relative_path,
          Rcpp::Named("package") = package));
  if (kernel_path.empty()) {
    throw std::runtime_error(
        "Kernel file not found via system.file: " + kernel_relative_path);
  }

  std::string lib_dir = Rcpp::as<std::string>(
      Rcpp::Function("system.file")(
          "cl", library_subdir,
          Rcpp::Named("package") = package));
  if (lib_dir.empty()) {
    throw std::runtime_error(
        "Library directory not found via system.file: " + library_subdir);
  }

  std::ifstream kf(kernel_path);
  if (!kf.is_open()) {
    throw std::runtime_error("Cannot open kernel file: " + kernel_path);
  }
  std::vector<std::string> klines;
  {
    std::string kl;
    while (std::getline(kf, kl)) klines.push_back(kl);
  }
  kf.close();

  std::vector<std::string> needed_stems = parse_cl_tag(klines, depends_tag);
  if (needed_stems.empty()) {
    return "";
  }

  std::string tsv_path = lib_dir + "/kernel_dependency_index.tsv";
  KernelDepIndex idx = read_tsv_index(tsv_path);

  std::unordered_set<std::string> needed_set(needed_stems.begin(), needed_stems.end());
  std::vector<std::string> to_load;
  to_load.reserve(needed_set.size());
  for (const auto& stem : idx.stems_ordered) {
    if (needed_set.count(stem)) to_load.push_back(stem);
  }

  std::string combined;
  for (const auto& stem : to_load) {
    std::string cl_path = lib_dir + "/" + stem + ".cl";
    std::ifstream cf(cl_path);
    if (!cf.is_open()) {
      throw std::runtime_error(
          "Library file not found for stem '" + stem + "': " + cl_path);
    }
    std::ostringstream oss;
    oss << cf.rdbuf();
    combined += oss.str() + "\n\n";
  }

  return combined;
}

namespace {

bool is_cl_tag_boundary(char c)
{
  return c == '\0' || std::isspace(static_cast<unsigned char>(c)) || c == ':';
}

void require_non_empty(const std::string& value, const char* arg_name)
{
  if (value.empty()) {
    throw std::runtime_error(
        std::string(arg_name) + " must be non-empty");
  }
}

std::string cl_path_join(const std::string& dir, const std::string& leaf)
{
  if (dir.empty()) {
    return leaf;
  }
  const char last = dir.back();
  if (last == '/' || last == '\\') {
    return dir + leaf;
  }
  return dir + "/" + leaf;
}

std::string format_stem_list(const std::vector<std::string>& stems)
{
  std::ostringstream oss;
  for (std::size_t i = 0; i < stems.size(); ++i) {
    if (i > 0) {
      oss << ", ";
    }
    oss << stems[i];
  }
  return oss.str();
}

std::vector<std::string> parse_cl_tag_strict(
    const std::vector<std::string>& lines,
    const std::string& tag)
{
  require_non_empty(tag, "depends_tag");

  const std::string needle = "@" + tag;
  std::unordered_set<std::string> seen;
  std::vector<std::string> result;

  for (const auto& line : lines) {
    std::size_t pos = 0;
    while (pos < line.size() &&
           (line[pos] == ' ' || line[pos] == '\t')) {
      ++pos;
    }
    if (pos + 1 >= line.size() || line[pos] != '/' || line[pos + 1] != '/') {
      continue;
    }
    pos += 2;
    while (pos < line.size() &&
           (line[pos] == ' ' || line[pos] == '\t')) {
      ++pos;
    }
    if (pos + needle.size() > line.size() ||
        line.compare(pos, needle.size(), needle) != 0) {
      continue;
    }
    pos += needle.size();
    if (pos < line.size() && !is_cl_tag_boundary(line[pos])) {
      continue;
    }
    while (pos < line.size() &&
           (line[pos] == ' ' || line[pos] == '\t')) {
      ++pos;
    }
    if (pos < line.size() && line[pos] == ':') {
      ++pos;
    }
    while (pos < line.size() &&
           (line[pos] == ' ' || line[pos] == '\t')) {
      ++pos;
    }

    std::istringstream ss(line.substr(pos));
    std::string tok;
    while (std::getline(ss, tok, ',')) {
      tok.erase(0, tok.find_first_not_of(" \t\r\n"));
      auto last = tok.find_last_not_of(" \t\r\n");
      if (last != std::string::npos) {
        tok.erase(last + 1);
      }
      if (tok.empty() || seen.count(tok)) {
        continue;
      }
      seen.insert(tok);
      result.push_back(tok);
    }
  }
  return result;
}

struct KernelDepStemIndex {
  std::vector<std::string> stems_ordered;
  std::unordered_set<std::string> known;
};

KernelDepStemIndex read_tsv_stem_index(const std::string& tsv_path)
{
  KernelDepStemIndex idx;
  std::ifstream f(tsv_path);
  if (!f.is_open()) {
    throw std::runtime_error(
        "kernel_dependency_index.tsv not found: " + tsv_path);
  }
  std::string line;
  bool header = true;
  while (std::getline(f, line)) {
    if (header) { header = false; continue; }
    if (!line.empty() && line.back() == '\r') line.pop_back();
    if (line.empty()) continue;

    auto tab = line.find('\t');
    std::string stem = (tab == std::string::npos) ? line : line.substr(0, tab);
    if (stem.empty()) continue;
    idx.stems_ordered.push_back(stem);
    idx.known.insert(stem);
  }
  return idx;
}

void validate_needed_stems_in_index(
    const std::vector<std::string>& needed_stems,
    const KernelDepStemIndex& idx,
    const std::string& depends_tag,
    const std::string& library_package,
    const std::string& tsv_path)
{
  std::vector<std::string> unknown;
  unknown.reserve(needed_stems.size());
  for (const auto& stem : needed_stems) {
    if (!idx.known.count(stem)) {
      unknown.push_back(stem);
    }
  }
  if (unknown.empty()) {
    return;
  }
  throw std::runtime_error(
      "Stems from '@" + depends_tag + "' were not found in "
      "kernel_dependency_index.tsv (library_package=" + library_package +
      ", path=" + tsv_path + "): " + format_stem_list(unknown));
}

std::string trim_manifest_field(std::string value)
{
  value.erase(0, value.find_first_not_of(" \t\r\n"));
  auto last = value.find_last_not_of(" \t\r\n");
  if (last != std::string::npos) {
    value.erase(last + 1);
  } else {
    value.clear();
  }
  return value;
}

ProgramPreloadKind parse_program_preload_kind(const std::string& kind_raw)
{
  const std::string kind = trim_manifest_field(kind_raw);
  if (kind == "file") {
    return ProgramPreloadKind::file;
  }
  if (kind == "library") {
    return ProgramPreloadKind::library;
  }
  throw std::runtime_error(
      "Unknown program_preload_manifest kind '" + kind_raw +
      "' (expected 'file' or 'library')");
}

int parse_manifest_rank(const std::string& rank_raw, const std::string& line_context)
{
  const std::string rank_text = trim_manifest_field(rank_raw);
  if (rank_text.empty()) {
    throw std::runtime_error(
        "Missing rank in program_preload_manifest row: " + line_context);
  }
  try {
    std::size_t consumed = 0;
    const int rank = std::stoi(rank_text, &consumed);
    if (consumed != rank_text.size() || rank < 1) {
      throw std::runtime_error("invalid rank");
    }
    return rank;
  } catch (const std::exception&) {
    throw std::runtime_error(
        "Invalid rank '" + rank_raw + "' in program_preload_manifest row: " +
        line_context);
  }
}

} // namespace

std::string load_library_for_kernel_cross_package(
    const std::string& kernel_relative_path,
    const std::string& kernel_package,
    const std::string& library_subdir,
    const std::string& library_package,
    const std::string& depends_tag)
{
  require_non_empty(kernel_relative_path, "kernel_relative_path");
  require_non_empty(kernel_package, "kernel_package");
  require_non_empty(library_subdir, "library_subdir");
  require_non_empty(library_package, "library_package");
  require_non_empty(depends_tag, "depends_tag");

  std::string kernel_path = Rcpp::as<std::string>(
      Rcpp::Function("system.file")(
          "cl", kernel_relative_path,
          Rcpp::Named("package") = kernel_package));
  if (kernel_path.empty()) {
    throw std::runtime_error(
        "Kernel file not found via system.file: cl/" + kernel_relative_path +
        " (package=" + kernel_package + ")");
  }

  std::string lib_dir = Rcpp::as<std::string>(
      Rcpp::Function("system.file")(
          "cl", library_subdir,
          Rcpp::Named("package") = library_package));
  if (lib_dir.empty()) {
    throw std::runtime_error(
        "Library directory not found via system.file: cl/" + library_subdir +
        " (package=" + library_package + ")");
  }

  std::ifstream kf(kernel_path);
  if (!kf.is_open()) {
    throw std::runtime_error(
        "Cannot open kernel file: " + kernel_path +
        " (package=" + kernel_package + ")");
  }
  std::vector<std::string> klines;
  {
    std::string kl;
    while (std::getline(kf, kl)) klines.push_back(kl);
  }
  kf.close();

  std::vector<std::string> needed_stems = parse_cl_tag_strict(klines, depends_tag);
  if (needed_stems.empty()) {
    return "";
  }

  const std::string tsv_path =
      cl_path_join(lib_dir, "kernel_dependency_index.tsv");
  KernelDepStemIndex idx = read_tsv_stem_index(tsv_path);
  validate_needed_stems_in_index(
      needed_stems, idx, depends_tag, library_package, tsv_path);

  std::unordered_set<std::string> needed_set(
      needed_stems.begin(), needed_stems.end());
  std::vector<std::string> to_load;
  to_load.reserve(needed_set.size());
  for (const auto& stem : idx.stems_ordered) {
    if (needed_set.count(stem)) {
      to_load.push_back(stem);
    }
  }
  if (to_load.empty()) {
    throw std::runtime_error(
        "No library stems matched '@" + depends_tag + "' in "
        "kernel_dependency_index.tsv (kernel=" + kernel_path +
        ", library_package=" + library_package + ", path=" + tsv_path + ")");
  }

  std::string combined;
  for (const auto& stem : to_load) {
    const std::string cl_path = cl_path_join(lib_dir, stem + ".cl");
    std::ifstream cf(cl_path);
    if (!cf.is_open()) {
      throw std::runtime_error(
          "Library file not found for stem '" + stem + "' "
          "(library_package=" + library_package + "): " + cl_path);
    }
    std::ostringstream oss;
    oss << cf.rdbuf();
    combined += oss.str() + "\n\n";
  }

  return combined;
}

std::vector<ProgramPreloadEntry> read_program_preload_manifest(
    const std::string& manifest_relative_path,
    const std::string& source_package)
{
  require_non_empty(manifest_relative_path, "manifest_relative_path");
  require_non_empty(source_package, "source_package");

  std::string manifest_path = Rcpp::as<std::string>(
      Rcpp::Function("system.file")(
          "cl", manifest_relative_path,
          Rcpp::Named("package") = source_package));
  if (manifest_path.empty()) {
    throw std::runtime_error(
        "program_preload_manifest not found via system.file: cl/" +
        manifest_relative_path + " (package=" + source_package + ")");
  }

  std::ifstream manifest_file(manifest_path);
  if (!manifest_file.is_open()) {
    throw std::runtime_error(
        "Cannot open program_preload_manifest: " + manifest_path +
        " (package=" + source_package + ")");
  }

  std::vector<ProgramPreloadEntry> entries;
  std::unordered_set<int> ranks_seen;
  std::string line;
  bool header = true;
  while (std::getline(manifest_file, line)) {
    if (header) {
      header = false;
      continue;
    }
    if (!line.empty() && line.back() == '\r') {
      line.pop_back();
    }
    line = trim_manifest_field(line);
    if (line.empty()) {
      continue;
    }

    std::vector<std::string> fields;
    {
      std::istringstream row(line);
      std::string field;
      while (std::getline(row, field, '\t')) {
        fields.push_back(trim_manifest_field(field));
      }
    }
    if (fields.size() < 3) {
      throw std::runtime_error(
          "program_preload_manifest row must have rank, kind, rel_path: " +
          line + " (path=" + manifest_path + ")");
    }

    ProgramPreloadEntry entry;
    entry.rank = parse_manifest_rank(fields[0], line);
    entry.kind = parse_program_preload_kind(fields[1]);
    entry.rel_path = fields[2];
    if (entry.rel_path.empty()) {
      throw std::runtime_error(
          "Empty rel_path in program_preload_manifest row: " + line +
          " (path=" + manifest_path + ")");
    }
    if (!ranks_seen.insert(entry.rank).second) {
      throw std::runtime_error(
          "Duplicate rank " + std::to_string(entry.rank) +
          " in program_preload_manifest (path=" + manifest_path + ")");
    }
    entries.push_back(std::move(entry));
  }

  if (entries.empty()) {
    throw std::runtime_error(
        "program_preload_manifest contains no entries (path=" +
        manifest_path + ", package=" + source_package + ")");
  }

  std::sort(entries.begin(), entries.end(),
            [](const ProgramPreloadEntry& a, const ProgramPreloadEntry& b) {
              return a.rank < b.rank;
            });
  return entries;
}

std::string load_program_preload_entries(
    const std::vector<ProgramPreloadEntry>& entries,
    const std::string& source_package,
    bool verbose)
{
  require_non_empty(source_package, "source_package");
  if (entries.empty()) {
    throw std::runtime_error(
        "load_program_preload_entries requires at least one entry");
  }

  std::string combined;
  for (std::size_t i = 0; i < entries.size(); ++i) {
    const ProgramPreloadEntry& entry = entries[i];
    std::string piece;
    if (entry.kind == ProgramPreloadKind::file) {
      piece = load_kernel_source(entry.rel_path, source_package);
    } else {
      piece = load_kernel_library(entry.rel_path, source_package, verbose);
    }
    if (piece.empty()) {
      throw std::runtime_error(
          "Empty preload source for rank " + std::to_string(entry.rank) +
          " (kind=" + (entry.kind == ProgramPreloadKind::file ? "file" : "library") +
          ", rel_path=" + entry.rel_path + ", package=" + source_package + ")");
    }
    if (!combined.empty()) {
      combined += "\n";
    }
    combined += piece;
  }
  return combined;
}

std::string load_program_preload(
    const std::string& manifest_relative_path,
    const std::string& source_package,
    bool verbose)
{
  std::vector<ProgramPreloadEntry> entries =
      read_program_preload_manifest(manifest_relative_path, source_package);
  return load_program_preload_entries(entries, source_package, verbose);
}

int get_opencl_core_count() {
#ifdef USE_OPENCL
  return std::max(1, detect_num_gpus_internal());
#else
  return 1;
#endif
}

std::string load_kernel_source_wrapper(std::string relative_path,
                                       std::string package ) {
  return load_kernel_source(relative_path, package);
}

std::string load_kernel_library_wrapper(std::string subdir,
                                       std::string package ,
                                       bool verbose ) {
  return load_kernel_library(subdir, package, verbose);
}

std::string load_program_preload_wrapper(
    std::string manifest_relative_path,
    std::string source_package,
    bool verbose) {
  return load_program_preload(manifest_relative_path, source_package, verbose);
}

std::string load_library_for_kernel_cross_package_wrapper(
    std::string kernel_relative_path,
    std::string kernel_package,
    std::string library_subdir,
    std::string library_package,
    std::string depends_tag) {
  return load_library_for_kernel_cross_package(
      kernel_relative_path, kernel_package, library_subdir,
      library_package, depends_tag);
}

}
