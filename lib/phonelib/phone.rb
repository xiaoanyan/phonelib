module Phonelib
  class Phone
    attr_reader :sanitized, :national_number

    def initialize(phone, country_data)
      @sanitized = sanitize_phone(phone)
      @analyzed_data = {}
      analyze_phone(country_data) unless @sanitized.empty?
    end

    def types
      @analyzed_data.flat_map {|iso2, data| data[:valid]}.uniq
    end

    def type
      types.first
    end

    def countries
      @analyzed_data.map {|iso2, data| iso2}
    end

    def country
      countries.first
    end

    def valid?
      @analyzed_data.select {|iso2, data| data[:valid].any? }.any?
    end

    def invalid?
      !valid?
    end

    def possible?
      @analyzed_data.select {|iso2, data| data[:possible].any? }.any?
    end

    def impossible?
      !possible?
    end

    def valid_for_country?(country)
      @analyzed_data.select {|iso2, data| country == iso2 &&
          data[:valid].any? }.any?
    end

    def invalid_for_country?(country)
      @analyzed_data.select {|iso2, data| country == iso2 &&
          data[:valid].any? }.empty?
    end

    private
    def analyze_phone(country_data)
      possible_countries = country_data.select do |data|
        @sanitized.start_with?(data[:countryCode])
      end

      possible_countries.each do |country_data|
        next if country_data[:types].empty?

        prefix_length = country_data[:countryCode].length
        @national_number = @sanitized[prefix_length..@sanitized.length]
        @analyzed_data[country_data[:id]] =
            get_all_number_types(@national_number, country_data[:types])
      end
    end

    def get_all_number_types(number, data)
      response = {valid: [], possible: []}

      return response if data[Core::GENERAL].empty?
      return response unless number_valid_and_possible?(number,
                                                        data[Core::GENERAL])

      (Core::TYPES.keys - Core::NOT_FOR_CHECK).each do |type|
        next if data[type].nil? || data[type].empty?

        response[:valid] << type if number_valid_and_possible?(number,
                                                               data[type])
        response[:possible] << type if number_possible?(number, data[type])
      end

      if number_valid_and_possible?(number, data[Core::FIXED_LINE])
        if data[Core::FIXED_LINE] == data[Core::MOBILE]
          response[:valid] << Core::FIXED_OR_MOBILE
        else
          response[:valid] << Core::FIXED_LINE
        end
      elsif number_valid_and_possible?(number, data[Core::MOBILE])
        response[:valid] << Core::MOBILE
      end

      if number_possible?(number, data[Core::FIXED_LINE])
        if data[Core::FIXED_LINE] == data[Core::MOBILE]
          response[:possible] << Core::FIXED_OR_MOBILE
        else
          response[:possible] << Core::FIXED_LINE
        end
      elsif number_possible?(number, data[Core::MOBILE])
        response[:possible] << Core::MOBILE
      end

      response
    end

    def number_valid_and_possible?(number, regexes)
      national_match = number.match(/^(?:#{regexes[:nationalNumberPattern]})$/)
      possible_match = number.match(/^(?:#{regexes[:possibleNumberPattern]})$/)

      national_match && possible_match &&
          national_match.to_s.length == number.length &&
          possible_match.to_s.length == number.length
    end

    def number_possible?(number, regexes)
      possible_match = number.match(/^(?:#{regexes[:possibleNumberPattern]})$/)
      possible_match && possible_match.to_s.length == number.length
    end

    def sanitize_phone(phone)
      phone.gsub(/[^0-9]+/, '')
    end
  end
end