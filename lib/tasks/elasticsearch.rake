# frozen_string_literal: true

namespace :elasticsearch do

  desc 'deletes all elasticsearch indices'
  task delete_indices: :environment do
    QuranUtils::ContentIndex.remove_indexes rescue nil

    begin
      Verse.__elasticsearch__.delete_index!
    rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
    end

    begin
      [Chapter, Juz, MuhsafPage].each do |model|
        model.__elasticsearch__.delete_index!
      end
    rescue Elasticsearch::Transport::Transport::Errors::NotFound => e
    end

    puts "Done"
  end

  desc 'reindex elasticsearch'
  task re_index: :environment do
    require 'parallel'

    ar_logger = ActiveRecord::Base.logger
    ActiveRecord::Base.logger = Logger.new(STDOUT)
    index_start = Time.now

    Verse.__elasticsearch__.create_index!
    [Chapter, Juz, MuhsafPage].each do |model|
      model.__elasticsearch__.create_index!
    end
    #QuranUtils::ContentIndex.setup_indexes

    Parallel.each([MuhsafPage, Chapter, Juz], in_processes: 3, progress: "Indexing chapters and juz data") do |model|
      model.import(force: true)
    end

    Verse.import

    puts "Setting up translation indexes"
    QuranUtils::ContentIndex.setup_language_index_classes

    Language.with_translations.each do |language|
      QuranUtils::ContentIndex.import_translation_for_language(language)
    end

    index_end = Time.now
    ActiveRecord::Base.logger = ar_logger

    puts "Done #{Verse.__elasticsearch__.refresh_index!}"
    puts "Indexing started at #{index_start.strftime("%B %d, %Y %I:%M %P")}"
    puts "Indexing ended at #{index_end.strftime("%B %d, %Y %I:%M %P")}"
  end
end
