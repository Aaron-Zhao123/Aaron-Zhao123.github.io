# Groups main-track papers at tier-one venues from the bibliography and exposes
# them as site.data["venue_counts"] for the publications page venue chart.
require "bibtex"

module Jekyll
  class VenueCountsGenerator < Generator
    safe true
    priority :high

    # Research areas in chart order; each area gets one fixed colour slot.
    AREAS = ["ML", "Graph", "NLP", "Vision", "Security", "Systems", "Journal"].freeze

    # How each area is described next to a venue on the page.
    AREA_LABELS = {
      "ML"       => "AI",
      "Graph"    => "AI & Graph Learning",
      "NLP"      => "AI & Natural Language Processing",
      "Vision"   => "AI & Computer Vision",
      "Security" => "Security & Privacy",
      "Systems"  => "Systems & Hardware",
      "Journal"  => "Scientific Journal",
    }.freeze

    # [label, area, pattern]. Patterns run against the venue string; order breaks ties.
    VENUES = [
      ["NeurIPS", "ML",       /NeurIPS|Neural Information Processing/],
      ["ICML",    "ML",       /\bICML\b|International Conference on Machine Learning/],
      ["ICLR",    "ML",       /\bICLR\b|International Conference on Learning Representations/],
      ["ECAI",    "ML",       /\bECAI\b|European Conference on Artificial Intelligence/],
      ["LoG",     "Graph",    /\bLoG\b|Learning on Graphs Conference/],
      ["MLSys",   "Systems",  /\bMLSys\b|SysML|Conference on Machine Learning and Systems/],
      ["ISCA",    "Systems",  /\bISCA\b|International Symposium on Computer Architecture/],
      ["FCCM",    "Systems",  /\bFCCM\b|Field-Programmable Custom Computing Machines/],
      ["FPT",     "Systems",  /\b(IC)?FPT\b|Field-Programmable Technology/],
      ["FPL",     "Systems",  /\bFPL\b|Field-Programmable Logic and Applications/],
      ["ACL",     "NLP",      /\bACL\b|Annual Meeting of the Association for Computational Linguistics/],
      ["NAACL",   "NLP",      /\bNAACL\b|North American Chapter/],
      ["EMNLP",   "NLP",      /\bEMNLP\b|Empirical Methods in Natural Language Processing/],
      ["S&P",     "Security", /IEEE Symposium on Security and Privacy/],
      ["EuroS&P", "Security", /EuroS\\?&P|European Symposium on Security and Privacy/],
      ["SaTML",   "Security", /SaTML|Secure and Trustworthy Machine Learning/],
      ["CVPR",    "Vision",   /\bCVPR\b|Computer Vision and Pattern Recognition/],
      ["ICCV",    "Vision",   /\bICCV\b|International Conference on Computer Vision/],
      ["ECCV",    "Vision",   /\bECCV\b|European Conference on Computer Vision/],
      ["Nature",  "Journal",  /\ANature\z/],
    ].freeze

    # Workshops, Findings and EuroMLSys share names with the main venues but don't count.
    EXCLUDE = /Workshop|Findings|EuroMLSys/i

    def generate(site)
      path = File.join(site.source, "_bibliography", "papers.bib")
      return unless File.exist?(path)

      papers = Hash.new { |h, k| h[k] = [] }
      BibTeX.open(path).each do |entry|
        next unless entry.respond_to?(:fields)
        venue = (entry[:booktitle] || entry[:journal]).to_s
        next if venue.empty? || venue =~ EXCLUDE
        match = VENUES.find { |_, _, pattern| venue =~ pattern }
        next unless match
        papers[match[0]] << { "title" => clean(entry[:title].to_s), "year" => entry[:year].to_s.to_i }
      end

      order = VENUES.map(&:first)
      rows = papers.map do |name, list|
        area = VENUES.find { |v| v[0] == name }[1]
        {
          "name" => name,
          "area" => area,
          "area_label" => AREA_LABELS[area],
          "slot" => AREAS.index(area) + 1,
          "count" => list.size,
          "papers" => list.sort_by { |p| [-p["year"], p["title"]] },
        }
      end
      rows.sort_by! { |r| [r["slot"], -r["count"], order.index(r["name"])] }
      # Venues sharing an area colour get successively deeper shades of it.
      rows.group_by { |r| r["area"] }.each_value { |rs| rs.each_with_index { |r, i| r["shade"] = [i, 4].min } }

      site.data["venue_counts"] = {
        "rows" => rows,
        "total" => rows.sum { |r| r["count"] },
      }
    end

    private

    def clean(title)
      title.gsub(/\\&/, "&").gsub(/[{}]/, "").gsub(/\s+/, " ").strip
    end
  end
end
