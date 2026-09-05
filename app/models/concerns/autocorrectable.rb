# A small, rudimentary autocorrect — not a real spellchecker/dictionary,
# just a hand-picked list of very common English typos, quietly fixed on
# save. Native browser spellcheck (spellcheck="true" on the form fields)
# covers everything else while typing; this covers the same ground again at
# submit time, including for API/programmatic writes that skip the browser
# entirely.
module Autocorrectable
  extend ActiveSupport::Concern

  CORRECTIONS = {
    "teh" => "the", "adress" => "address", "arguement" => "argument",
    "beleive" => "believe", "calender" => "calendar", "definately" => "definitely",
    "existance" => "existence", "occured" => "occurred", "occuring" => "occurring",
    "recieve" => "receive", "recieved" => "received", "seperate" => "separate",
    "seperately" => "separately", "wich" => "which", "wierd" => "weird",
    "accomodate" => "accommodate", "acheive" => "achieve", "acheived" => "achieved",
    "becuase" => "because", "buisness" => "business", "commited" => "committed",
    "concious" => "conscious", "enviroment" => "environment", "goverment" => "government",
    "independant" => "independent", "intergrate" => "integrate", "maintainance" => "maintenance",
    "neccessary" => "necessary", "noticable" => "noticeable", "occassion" => "occasion",
    "priviledge" => "privilege", "publically" => "publicly", "refered" => "referred",
    "succesful" => "successful", "succesfully" => "successfully", "thier" => "their",
    "truely" => "truly", "untill" => "until"
  }.freeze

  WORD_PATTERN = /\b(#{Regexp.union(CORRECTIONS.keys)})\b/i

  def self.correct_text(text)
    text.gsub(WORD_PATTERN) { |match| match_case(CORRECTIONS.fetch(match.downcase), match) }
  end

  def self.match_case(replacement, original)
    return replacement.upcase if original == original.upcase
    return replacement.sub(/\A./) { |c| c.upcase } if original[0] == original[0].upcase

    replacement
  end

  included do
    class_attribute :autocorrect_plain_attributes, default: []
    class_attribute :autocorrect_rich_text_attributes, default: []
    before_validation :autocorrect_typos
  end

  class_methods do
    # autocorrects :title, rich_text: :content
    def autocorrects(*plain_attributes, rich_text: [])
      self.autocorrect_plain_attributes = plain_attributes
      self.autocorrect_rich_text_attributes = Array(rich_text)
    end
  end

  private
    def autocorrect_typos
      autocorrect_plain_attributes.each { |attribute| autocorrect_plain_attribute(attribute) }
      autocorrect_rich_text_attributes.each { |attribute| autocorrect_rich_text_attribute(attribute) }
    end

    def autocorrect_plain_attribute(attribute)
      value = public_send(attribute)
      return if value.blank?

      corrected = Autocorrectable.correct_text(value)
      public_send("#{attribute}=", corrected) if corrected != value
    end

    def autocorrect_rich_text_attribute(attribute)
      rich_text = public_send(attribute)
      return if rich_text.body.blank?

      fragment = rich_text.body.fragment.source
      changed = false

      fragment.traverse do |node|
        next unless node.text?

        corrected = Autocorrectable.correct_text(node.content)
        if corrected != node.content
          node.content = corrected
          changed = true
        end
      end

      public_send("#{attribute}=", fragment.to_html) if changed
    end
end
